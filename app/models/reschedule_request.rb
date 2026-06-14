# frozen_string_literal: true

class RescheduleRequest < ApplicationRecord
  belongs_to :tenant
  belongs_to :booking
  belongs_to :requested_by, class_name: "User"

  validates :old_start_time, :old_end_time, :new_start_time, :new_end_time, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending accepted rejected expired] }
  validate :end_time_after_start_time
  validate :new_start_time_in_future, on: :create
  validate :booking_is_reschedulable, on: :create
  validate :no_overlapping_bookings, if: :pending?

  scope :pending, -> { where(status: "pending") }
  scope :accepted, -> { where(status: "accepted") }
  scope :rejected, -> { where(status: "rejected") }
  scope :expired, -> { where(status: "expired") }

  def accept!
    transaction do
      update!(status: "accepted")
      booking.update!(
        start_time: new_start_time,
        end_time: new_end_time
      )
      # Re-schedule background jobs if any
      booking.transitions.create!(
        event: "rescheduled",
        from_state: booking.aasm_state,
        to_state: booking.aasm_state,
        metadata: { reschedule_request_id: id }
      )
    end
  end

  def reject!
    update!(status: "rejected")
  end

  def pending?
    status == "pending"
  end

  private

  def end_time_after_start_time
    return unless new_start_time && new_end_time
    if new_end_time <= new_start_time
      errors.add(:new_end_time, "must be after new start time")
    end
  end

  def new_start_time_in_future
    return unless new_start_time
    if new_start_time < Time.current
      errors.add(:new_start_time, "must be in the future")
    end
  end

  def booking_is_reschedulable
    return unless booking
    unless %w[paid confirmed confirmed_free authorized pending payment_initiated].include?(booking.aasm_state)
      errors.add(:booking, "cannot be rescheduled from state: #{booking.aasm_state}")
    end
  end

  def no_overlapping_bookings
    return unless booking && new_start_time && new_end_time

    overlapping = Booking.where(expert_id: booking.expert_id)
                         .where.not(id: booking.id)
                         .confirmed_or_paid
                         .where("start_time < ? AND end_time > ?", new_end_time, new_start_time)

    if overlapping.exists?
      errors.add(:base, "Expert has a conflicting booking at this new time")
    end
  end
end
