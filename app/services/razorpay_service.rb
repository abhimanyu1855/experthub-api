# frozen_string_literal: true

class RazorpayService
  class RazorpayError < StandardError; end

  # Create an Order in Razorpay for a booking
  def self.create_order(booking:, tenant:)
    payment_config = tenant.payment_configs.razorpay.active.first
    raise RazorpayError, "Razorpay not configured for this tenant" unless payment_config

    key_id = payment_config.publishable_key
    key_secret = payment_config.encrypted_credentials

    # Razorpay expects basic auth: key_id:key_secret
    conn = Faraday.new(url: "https://api.razorpay.com") do |f|
      f.request :authorization, :basic, key_id, key_secret
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    response = conn.post("/v1/orders") do |req|
      req.body = {
        amount: booking.client_total_cents, # Amount in paise (cents equivalent)
        currency: booking.currency,
        receipt: "booking_#{booking.id}",
        notes: {
          booking_id: booking.id.to_s,
          tenant_id: tenant.id.to_s
        }
      }
    end

    if response.success?
      order_id = response.body["id"]
      booking.update!(
        metadata: (booking.metadata || {}).merge(
          "payment_gateway" => "razorpay",
          "razorpay_order_id" => order_id
        )
      )
      {
        order_id: order_id,
        key_id: key_id,
        amount: booking.client_total_cents,
        currency: booking.currency
      }
    else
      raise RazorpayError, "Razorpay Order creation failed: #{response.body}"
    end
  end

  # Process payout transfer via Razorpay Route
  def self.transfer_to_expert(booking)
    expert_profile = booking.service.expert_profile
    payout_account = expert_profile.payout_accounts.razorpay.active.first
    return unless payout_account&.account_identifier.present?

    tenant = booking.tenant
    payment_config = tenant.payment_configs.razorpay.active.first
    return unless payment_config

    key_id = payment_config.publishable_key
    key_secret = payment_config.encrypted_credentials

    # We transfer money for a specific captured payment. We need the payment ID.
    payment_record = booking.payment_records.where(gateway: "razorpay", status: "succeeded").first
    return unless payment_record&.provider_id.present?

    conn = Faraday.new(url: "https://api.razorpay.com") do |f|
      f.request :authorization, :basic, key_id, key_secret
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    response = conn.post("/v1/payments/#{payment_record.provider_id}/transfers") do |req|
      req.body = {
        transfers: [
          {
            account: payout_account.account_identifier,
            amount: booking.expert_payout_cents,
            currency: booking.currency,
            notes: {
              booking_id: booking.id.to_s
            }
          }
        ]
      }
    end

    if response.success?
      transfer_id = response.body.dig("items", 0, "id")
      booking.update!(
        metadata: (booking.metadata || {}).merge("razorpay_transfer_id" => transfer_id)
      )
    else
      Rails.logger.error "Razorpay Route Transfer failed for booking #{booking.id}: #{response.body}"
    end
  end

  # Verify and handle webhook
  def self.handle_webhook(payload:, signature:, tenant:)
    payment_config = tenant.payment_configs.razorpay.active.first
    raise RazorpayError, "Razorpay not configured for this tenant" unless payment_config

    webhook_secret = tenant.setting("razorpay_webhook_secret")
    
    if signature.present? && webhook_secret.present?
      verify_signature!(payload, signature, webhook_secret)
    elsif Rails.env.production?
      raise RazorpayError, "Razorpay webhook signature verification is required in production"
    end

    event = JSON.parse(payload)
    case event["event"]
    when "payment.captured", "order.paid"
      handle_payment_captured(event, tenant)
    when "payment.failed"
      handle_payment_failed(event, tenant)
    else
      Rails.logger.info "Unhandled Razorpay event: #{event['event']}"
    end
  end

  private_class_method def self.verify_signature!(payload, signature, secret)
    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      raise RazorpayError, "Invalid Razorpay signature"
    end
  end

  private_class_method def self.handle_payment_captured(event, _tenant)
    payment = event.dig("payload", "payment", "entity")
    order_id = payment["order_id"]
    payment_id = payment["id"]

    return unless order_id

    # Find booking matching this Razorpay order ID in JSONB metadata
    booking = Booking.where("metadata ->> 'razorpay_order_id' = ?", order_id).first
    return unless booking

    BookingService.payment_succeeded(
      booking: booking,
      stripe_payment_intent_id: payment_id,
      gateway: "razorpay"
    )
  end


  private_class_method def self.handle_payment_failed(event, _tenant)
    payment = event.dig("payload", "payment", "entity")
    order_id = payment["order_id"]

    return unless order_id

    booking = Booking.where("metadata ->> 'razorpay_order_id' = ?", order_id).first
    return unless booking

    booking.fail_payment! if booking.may_fail_payment?
  end
end
