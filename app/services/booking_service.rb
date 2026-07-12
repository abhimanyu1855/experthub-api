# frozen_string_literal: true

# Ported from mytin: transaction_service/ + transaction.rb + ConfirmConversation
# Orchestrates the full booking lifecycle: create → pay → confirm → complete
class BookingService
  class BookingError < StandardError; end
  class SlotUnavailable < BookingError; end
  class PaymentFailed < BookingError; end

  # Create a new booking
  # mytin equivalent: TransactionService::Create + TransactionService::Process
  def self.create(service:, client:, start_time:, end_time:, tenant:)
    expert = service.expert_profile.user

    # Clean up any stale pending/initiated bookings by the SAME client for this service/slot
    # so we don't have multiple pending bookings for the same slot by the same client.
    Booking.where(client: client, expert: expert)
           .where(aasm_state: %w[pending payment_initiated payment_action_required])
           .where("start_time < ? AND end_time > ?", end_time, start_time)
           .destroy_all rescue nil

    # Validate slot is still available
    unless slot_available?(service: service, start_time: start_time, end_time: end_time, client_id: client.id)
      raise SlotUnavailable, "This time slot is no longer available"
    end

    booking = Booking.new(
      service: service,
      tenant: tenant,
      client: client,
      expert: expert,
      start_time: start_time,
      end_time: end_time,
      price_cents: service.price_cents,
      currency: service.currency,
      duration_minutes: service.duration_minutes,
      cancellation_policy: service.cancellation_policy || tenant.cancellation_policies.active.first
    )

    # Apply referral credits as discount before saving
    ReferralService.apply_credits!(booking)

    ActiveRecord::Base.transaction do
      booking.save!

      if service.free?
        booking.confirm_free!
        enqueue_free_booking_jobs(booking)
      else
        booking.initiate_payment!
        # Stripe PaymentIntent will be created by the controller
      end
    end

    booking
  end

  # Confirm after payment succeeds
  # mytin equivalent: after_transition(to: :paid) in state_machine
  def self.payment_succeeded(booking:, stripe_payment_intent_id:, gateway: "stripe")
    ActiveRecord::Base.transaction do
      # Double check if slot is still available (i.e. not confirmed/paid by someone else)
      confirmed_conflict = Booking.where(expert_id: booking.expert_id)
                                  .where.not(id: booking.id)
                                  .confirmed_or_paid
                                  .where("start_time < ? AND end_time > ?", booking.end_time, booking.start_time)

      if confirmed_conflict.exists?
        # Slot is already paid/confirmed by someone else!
        # Mark booking as errored / requires refund
        booking.update!(
          stripe_payment_intent_id: stripe_payment_intent_id,
          payment_status: "failed"
        )
        booking.mark_error! if booking.may_mark_error?
        raise SlotUnavailable, "This slot was already booked and paid for by another user. A refund will be processed."
      end

      if gateway == "stripe"
        booking.update!(stripe_payment_intent_id: stripe_payment_intent_id)
      else
        booking.update!(payment_status: "paid")
      end

      booking.authorize_payment! if booking.may_authorize_payment?
      booking.mark_paid! if booking.may_mark_paid?

      # Redeem active referral credits up to the discount amount
      ReferralService.redeem_credits!(booking)

      # Award referral credits if this is the user's first paid booking
      ReferralService.check_and_reward!(booking)

      booking.payment_records.create!(
        gateway: gateway,
        provider_id: stripe_payment_intent_id,
        amount_cents: booking.client_total_cents,
        currency: booking.currency,
        status: "succeeded"
      )

      enqueue_paid_booking_jobs(booking)
    end

    booking
  end


  # Auto-confirm after session ends + grace period and trigger expert payout
  # mytin equivalent: ConfirmConversation#confirm!
  def self.auto_confirm(booking)
    return unless booking.may_confirm?

    booking.confirm!
    case booking.payment_records.where(status: "succeeded").order(:created_at).last&.gateway
    when "razorpay"
      RazorpayService.transfer_to_expert(booking)
    else
      StripeService.transfer_to_expert(booking)
    end
  rescue StripeService::StripeError => e
    Rails.logger.error "Stripe transfer failed for booking ##{booking.id}: #{e.message}"
    # Payout failure is non-fatal — booking is already confirmed; ops team should retry
  rescue RazorpayService::RazorpayError => e
    Rails.logger.error "Razorpay transfer failed for booking ##{booking.id}: #{e.message}"
  end

  private_class_method def self.slot_available?(service:, start_time:, end_time:, client_id: nil)
    # Check for confirmed/paid bookings (always block)
    confirmed_conflict = Booking.where(expert_id: service.expert_profile.user_id)
                                .confirmed_or_paid
                                .where("start_time < ? AND end_time > ?", end_time, start_time)

    return false if confirmed_conflict.exists?

    # Check for active checkout holds (pending bookings from OTHER clients in the last 15 minutes)
    active_holds = Booking.where(expert_id: service.expert_profile.user_id)
                          .where(aasm_state: %w[pending payment_initiated payment_action_required authorized])
                          .where("created_at > ?", 15.minutes.ago)
                          .where("start_time < ? AND end_time > ?", end_time, start_time)

    if client_id
      active_holds = active_holds.where.not(client_id: client_id)
    end

    !active_holds.exists?
  end

  private_class_method def self.safe_enqueue_future_job(job_class, booking_id, wait_until:)
    job_class.set(wait_until: wait_until).perform_later(booking_id)
  rescue NotImplementedError => e
    Rails.logger.warn "Skipped enqueuing #{job_class.name} for booking ##{booking_id} because the active queue adapter does not support future scheduling: #{e.message}"
  end

  private_class_method def self.enqueue_free_booking_jobs(booking)
    NewBookingNotificationJob.perform_later(booking.id)
    safe_enqueue_future_job(BookingReminderJob, booking.id, wait_until: booking.start_time - 10.minutes)
    SendWebhookJob.perform_later(booking.id, "booking.created_free")
  end

  private_class_method def self.enqueue_paid_booking_jobs(booking)
    CreateVideoRoomJob.perform_later(booking.id)
    SendBookingReceiptJob.perform_later(booking.id)
    NewBookingNotificationJob.perform_later(booking.id)
    safe_enqueue_future_job(BookingReminderJob, booking.id, wait_until: booking.start_time - 10.minutes)
    safe_enqueue_future_job(BookingStartedJob, booking.id, wait_until: booking.start_time)
    safe_enqueue_future_job(BookingEndedJob, booking.id, wait_until: booking.end_time + 2.minutes)
    safe_enqueue_future_job(ConfirmBookingJob, booking.id, wait_until: booking.auto_confirm_at)
    SendWebhookJob.perform_later(booking.id, "booking.paid")
  end
end
