# frozen_string_literal: true

# Ported from mytin: stripe_service/ + transaction.rb commission methods
# Handles PaymentIntent creation, webhook processing, and Connect transfers
class StripeService
  class StripeError < StandardError; end

  # Create a PaymentIntent for a booking
  # mytin equivalent: StripeService::CreatePayment
  def self.create_payment_intent(booking:, tenant:)
    payment_config = tenant.payment_configs.stripe.active.first
    raise StripeError, "Stripe not configured for this tenant" unless payment_config

    Stripe.api_key = secret_key_for(payment_config)

    intent = Stripe::PaymentIntent.create(
      amount: booking.client_total_cents,
      currency: booking.currency.downcase,
      metadata: {
        booking_id: booking.id,
        tenant_id: tenant.id,
        expert_id: booking.expert_id,
        client_id: booking.client_id,
        platform_commission_cents: booking.commission_cents,
        expert_payout_cents: booking.expert_payout_cents
      },
      automatic_payment_methods: { enabled: true }
    )

    booking.update!(stripe_payment_intent_id: intent.id)

    {
      client_secret: intent.client_secret,
      payment_intent_id: intent.id,
      amount: intent.amount,
      currency: intent.currency,
      gateway: "stripe",
      publishable_key: payment_config.publishable_key
    }
  end

  def self.create_express_account(expert_profile:, tenant:, email:)
    payment_config = tenant.payment_configs.stripe.active.first
    raise StripeError, "Stripe not configured for this tenant" unless payment_config

    return expert_profile.stripe_account_id if expert_profile.stripe_account_id.present?

    Stripe.api_key = secret_key_for(payment_config)

    account = Stripe::Account.create(
      type: "express",
      email: email,
      capabilities: {
        transfers: { requested: true },
        card_payments: { requested: true }
      },
      metadata: {
        tenant_id: tenant.id,
        expert_profile_id: expert_profile.id,
        user_id: expert_profile.user_id
      }
    )

    expert_profile.update!(stripe_account_id: account.id)
    account.id
  end

  def self.create_account_link(expert_profile:, tenant:, refresh_url:, return_url:)
    payment_config = tenant.payment_configs.stripe.active.first
    raise StripeError, "Stripe not configured for this tenant" unless payment_config
    raise StripeError, "Stripe account not created for this expert" if expert_profile.stripe_account_id.blank?

    Stripe.api_key = secret_key_for(payment_config)

    Stripe::AccountLink.create(
      account: expert_profile.stripe_account_id,
      refresh_url: refresh_url,
      return_url: return_url,
      type: "account_onboarding"
    )
  end

  def self.refund_booking(booking, amount_cents:)
    amount_cents = amount_cents.to_i
    return nil if amount_cents <= 0
    raise StripeError, "Booking has no Stripe PaymentIntent" if booking.stripe_payment_intent_id.blank?

    payment_config = booking.tenant.payment_configs.stripe.active.first
    raise StripeError, "Stripe not configured for this tenant" unless payment_config

    Stripe.api_key = secret_key_for(payment_config)

    Stripe::Refund.create(
      payment_intent: booking.stripe_payment_intent_id,
      amount: amount_cents
    )
  end

  # Handle webhook events
  # mytin equivalent: StripeController#webhook (50+ line switch statement)
  def self.handle_webhook(event:, tenant:)
    case event.type
    when "payment_intent.succeeded"
      handle_payment_succeeded(event.data.object, tenant)
    when "payment_intent.payment_failed"
      handle_payment_failed(event.data.object, tenant)
    else
      Rails.logger.info "Unhandled Stripe webhook: #{event.type}"
    end
  end

  # Transfer payout to expert via Stripe Connect
  # mytin equivalent: StripeService::CreateTransfer
  def self.transfer_to_expert(booking)
    expert_profile = booking.service.expert_profile
    if booking.stripe_transfer_id.present?
      Rails.logger.warn "Stripe transfer already exists for booking ##{booking.id}; skipping duplicate payout"
      return nil
    end

    unless expert_profile.stripe_account_id.present?
      Rails.logger.warn "Stripe payout pending for booking ##{booking.id}: expert has no connected account"
      booking.update!(
        metadata: (booking.metadata || {}).merge(
          "payout_status" => "pending",
          "payout_pending_reason" => "missing_stripe_account"
        )
      )
      return nil
    end

    payment_config = booking.tenant.payment_configs.stripe.active.first
    raise StripeError, "Stripe not configured for this tenant" unless payment_config

    Stripe.api_key = secret_key_for(payment_config)

    transfer = Stripe::Transfer.create(
      amount: booking.expert_payout_cents,
      currency: booking.currency.downcase,
      destination: expert_profile.stripe_account_id,
      transfer_group: "booking_#{booking.id}",
      metadata: { booking_id: booking.id }
    )

    booking.update!(
      stripe_transfer_id: transfer.id,
      metadata: (booking.metadata || {}).merge("payout_status" => "paid")
    )
    transfer
  end

  def self.transfer_subscription_payout(subscription)
    expert_profile = subscription.subscription_plan.expert_profile
    return unless expert_profile&.stripe_account_id.present?

    price_cents = subscription.subscription_plan.price_cents
    commission_pct = 10
    expert_payout_cents = price_cents - (price_cents * commission_pct / 100).to_i

    payment_config = subscription.tenant.payment_configs.stripe.active.first
    return unless payment_config

    Stripe.api_key = secret_key_for(payment_config)

    transfer = Stripe::Transfer.create(
      amount: expert_payout_cents,
      currency: subscription.subscription_plan.currency.downcase,
      destination: expert_profile.stripe_account_id,
      transfer_group: "subscription_#{subscription.id}",
      metadata: {
        subscription_id: subscription.id,
        expert_payout_cents: expert_payout_cents,
        platform_commission_cents: price_cents - expert_payout_cents
      }
    )

    subscription.update!(
      stripe_subscription_id: transfer.id,
      status: "active"
    )
    transfer
  rescue => e
    Rails.logger.error "Stripe subscription Connect transfer failed: #{e.message}"
    nil
  end

  private

  def self.handle_payment_succeeded(payment_intent, _tenant)
    booking = Booking.find_by!(stripe_payment_intent_id: payment_intent.id)
    BookingService.payment_succeeded(
      booking: booking,
      stripe_payment_intent_id: payment_intent.id
    )
  end

  def self.handle_payment_failed(payment_intent, _tenant)
    booking = Booking.find_by(stripe_payment_intent_id: payment_intent.id)
    return unless booking

    booking.fail_payment! if booking.may_fail_payment?
  end

  def self.secret_key_for(payment_config)
    credentials = payment_config.encrypted_credentials
    parsed = JSON.parse(credentials) if credentials.is_a?(String) && credentials.strip.start_with?("{")
    (parsed && (parsed["secret_key"] || parsed["api_key"])) || credentials
  rescue JSON::ParserError
    credentials
  end
end
