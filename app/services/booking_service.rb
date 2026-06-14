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

    # Validate slot is still available
    unless slot_available?(service: service, start_time: start_time, end_time: end_time)
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

  private_class_method def self.slot_available?(service:, start_time:, end_time:)
    !Booking.where(expert_id: service.expert_profile.user_id)
            .confirmed_or_paid
            .where("start_time < ? AND end_time > ?", end_time, start_time)
            .exists?
  end

  private_class_method def self.enqueue_free_booking_jobs(booking)
    NewBookingNotificationJob.perform_later(booking.id)
    BookingReminderJob.set(wait_until: booking.start_time - 10.minutes).perform_later(booking.id)
    SendWebhookJob.perform_later(booking.id, "booking.created_free")
  end

  private_class_method def self.enqueue_paid_booking_jobs(booking)
    CreateVideoRoomJob.perform_later(booking.id)
    SendBookingReceiptJob.perform_later(booking.id)
    NewBookingNotificationJob.perform_later(booking.id)
    BookingReminderJob.set(wait_until: booking.start_time - 10.minutes).perform_later(booking.id)
    BookingStartedJob.set(wait_until: booking.start_time).perform_later(booking.id)
    BookingEndedJob.set(wait_until: booking.end_time + 2.minutes).perform_later(booking.id)
    ConfirmBookingJob.set(wait_until: booking.auto_confirm_at).perform_later(booking.id)
    SendWebhookJob.perform_later(booking.id, "booking.paid")
  end
end
