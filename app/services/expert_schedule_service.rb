# frozen_string_literal: true

# Central schedule conflict detection for an expert's 1:1 bookings and group sessions.
class ExpertScheduleService
  OVERLAP_SQL = "start_time < ? AND end_time > ?"

  # Paid / confirmed — always block the calendar.
  BLOCKING_BOOKING_STATES = %w[
    authorized paid confirmed confirmed_free
  ].freeze

  # In-flight checkouts — block until they expire or complete.
  CHECKOUT_HOLD_STATES = %w[
    pending payment_initiated payment_action_required
  ].freeze

  CHECKOUT_HOLD_TTL = 30.minutes

  class << self
    def slot_taken?(expert_profile:, start_time:, end_time:, exclude_booking_id: nil, exclude_group_session_id: nil)
      conflicting_booking?(
        expert_id: expert_profile.user_id,
        start_time: start_time,
        end_time: end_time,
        exclude_booking_id: exclude_booking_id
      ) || conflicting_group_session?(
        expert_profile_id: expert_profile.id,
        start_time: start_time,
        end_time: end_time,
        exclude_group_session_id: exclude_group_session_id
      )
    end

    def conflicting_booking?(expert_id:, start_time:, end_time:, exclude_booking_id: nil)
      scope = overlapping_bookings(expert_id: expert_id, start_time: start_time, end_time: end_time, exclude_booking_id: exclude_booking_id)

      return true if scope.where(aasm_state: BLOCKING_BOOKING_STATES).exists?

      scope.where(aasm_state: CHECKOUT_HOLD_STATES)
           .where("created_at > ?", CHECKOUT_HOLD_TTL.ago)
           .exists?
    end

    def conflicting_group_session?(expert_profile_id:, start_time:, end_time:, exclude_group_session_id: nil)
      scope = GroupSession.where(expert_profile_id: expert_profile_id)
                          .where(OVERLAP_SQL, end_time, start_time)
      scope = scope.where.not(id: exclude_group_session_id) if exclude_group_session_id
      scope.exists?
    end

    # Intervals that should hide 1:1 availability for a date range.
    def blocking_intervals(expert_profile:, range_start:, range_end:, exclude_client_id: nil)
      expert_id = expert_profile.user_id

      bookings = overlapping_bookings(
        expert_id: expert_id,
        start_time: range_start,
        end_time: range_end
      )

      if exclude_client_id
        blocking_bookings = bookings.where(
          "aasm_state IN (?) OR (aasm_state IN (?) AND created_at > ? AND client_id != ?)",
          BLOCKING_BOOKING_STATES,
          CHECKOUT_HOLD_STATES,
          CHECKOUT_HOLD_TTL.ago,
          exclude_client_id
        )
      else
        blocking_bookings = bookings.where(
          "aasm_state IN (?) OR (aasm_state IN (?) AND created_at > ?)",
          BLOCKING_BOOKING_STATES,
          CHECKOUT_HOLD_STATES,
          CHECKOUT_HOLD_TTL.ago
        )
      end

      booking_intervals = blocking_bookings.pluck(:start_time, :end_time).map { |s, e| { start: s, end: e } }

      session_intervals = GroupSession.where(expert_profile_id: expert_profile.id)
                                      .where(OVERLAP_SQL, range_end, range_start)
                                      .pluck(:start_time, :end_time)
                                      .map { |s, e| { start: s, end: e } }

      booking_intervals + session_intervals
    end

    def with_expert_lock(expert_id)
      ActiveRecord::Base.transaction do
        # Serialize create/pay/reschedule for the same expert to prevent double-book races.
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql_array(["SELECT pg_advisory_xact_lock(?)", expert_id.to_i])
        )
        yield
      end
    end

    private

    def overlapping_bookings(expert_id:, start_time:, end_time:, exclude_booking_id: nil)
      scope = Booking.where(expert_id: expert_id).where(OVERLAP_SQL, end_time, start_time)
      scope = scope.where.not(id: exclude_booking_id) if exclude_booking_id
      scope
    end
  end
end
