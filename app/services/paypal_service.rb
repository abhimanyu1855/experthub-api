# frozen_string_literal: true

class PaypalService
  class PaypalError < StandardError; end

  def self.handle_webhook(event_data, _tenant)
    raise PaypalError, "PayPal webhook signature verification is not implemented" if Rails.env.production?

    event_type = event_data["event_type"]

    case event_type
    when "PAYMENT.CAPTURE.COMPLETED", "CHECKOUT.ORDER.APPROVED"
      resource = event_data["resource"]
      order_id = resource["id"] || resource["parent_payment"]

      return unless order_id

      # Find booking by paypal_order_id in metadata
      booking = Booking.where("metadata ->> 'paypal_order_id' = ?", order_id).first
      return unless booking

      BookingService.payment_succeeded(
        booking: booking,
        stripe_payment_intent_id: order_id,
        gateway: "paypal"
      )
    end
  end
end
