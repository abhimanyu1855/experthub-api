# frozen_string_literal: true

# WebhookService — handles idempotent processing of incoming Stripe webhooks.
# Replaces mytin's manual and duplicate database logs with clean, cache-based
# idempotency verification and structured routing to StripeService.
class WebhookService
  class WebhookError < StandardError; end

  # Process Stripe webhook
  # @param payload [String] raw request body
  # @param sig_header [String] Stripe-Signature header
  # @param tenant [Tenant]
  def self.process_stripe_webhook(payload:, sig_header:, tenant:)
    payment_config = tenant.payment_configs.stripe.active.first
    raise WebhookError, "Stripe not configured for this tenant" unless payment_config

    # Extract webhook secret from tenant settings
    webhook_secret = tenant.setting("stripe_webhook_secret")

    begin
      event = if sig_header.present? && webhook_secret.present?
                Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
              else
                if Rails.env.production?
                  raise WebhookError, "Stripe webhook signature verification is required in production"
                end

                # Fallback for development/testing when signature verification is not enabled
                Stripe::Event.construct_from(JSON.parse(payload, symbolize_names: true))
              end
    rescue JSON::ParserError => e
      raise WebhookError, "Invalid JSON payload: #{e.message}"
    rescue Stripe::SignatureVerificationError => e
      raise WebhookError, "Invalid Stripe signature: #{e.message}"
    end

    # Idempotency guard: prevent duplicate processing of the same event
    if event_already_processed?(event.id)
      Rails.logger.warn "Stripe webhook event #{event.id} already processed. Skipping."
      return { status: :ignored, reason: "Already processed" }
    end

    # Process event
    StripeService.handle_webhook(event: event, tenant: tenant)

    # Mark as processed
    mark_event_as_processed(event.id)

    { status: :success }
  end

  # Process Razorpay webhook
  def self.process_razorpay_webhook(payload:, signature:, tenant:)
    webhook_secret = tenant.setting("razorpay_webhook_secret")
    if Rails.env.production? && (signature.blank? || webhook_secret.blank?)
      raise WebhookError, "Razorpay webhook signature verification is required in production"
    end

    event = JSON.parse(payload) rescue nil
    event_id = event&.dig("id")

    if event_id.present? && event_already_processed?(event_id)
      Rails.logger.warn "Razorpay webhook event #{event_id} already processed. Skipping."
      return { status: :ignored, reason: "Already processed" }
    end

    RazorpayService.handle_webhook(
      payload: payload,
      signature: signature,
      tenant: tenant
    )

    mark_event_as_processed(event_id) if event_id.present?

    { status: :success }
  end

  # Process PayPal webhook
  def self.process_paypal_webhook(payload:, tenant:)
    if Rails.env.production?
      return { status: :not_implemented, reason: "PayPal webhook signature verification is not implemented" }
    end

    event = JSON.parse(payload) rescue nil
    event_id = event&.dig("id")

    if event_id.present? && event_already_processed?(event_id)
      Rails.logger.warn "PayPal webhook event #{event_id} already processed. Skipping."
      return { status: :ignored, reason: "Already processed" }
    end

    PaypalService.handle_webhook(event, tenant)

    mark_event_as_processed(event_id) if event_id.present?

    { status: :success }
  end

  # Process Payfast webhook
  def self.process_payfast_webhook(params:, tenant:)
    if Rails.env.production?
      return { status: :not_implemented, reason: "Payfast webhook signature verification is not implemented" }
    end

    event_id = params["pf_payment_id"]

    if event_id.present? && event_already_processed?(event_id)
      Rails.logger.warn "Payfast webhook event #{event_id} already processed. Skipping."
      return { status: :ignored, reason: "Already processed" }
    end

    PayfastService.handle_webhook(params, tenant)

    mark_event_as_processed(event_id) if event_id.present?

    { status: :success }
  end

  private

  def self.event_already_processed?(event_id)
    val = Rails.cache.read("webhook_processed:#{event_id}")
    val.present?
  end

  def self.mark_event_as_processed(event_id)
    Rails.cache.write("webhook_processed:#{event_id}", true, expires_in: 1.day)
  end
end

