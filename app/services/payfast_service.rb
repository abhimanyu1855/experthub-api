# frozen_string_literal: true

class PayfastService
  class PayfastError < StandardError; end

  def self.handle_webhook(params, _tenant)
    raise PayfastError, "Payfast webhook signature verification is not implemented" if Rails.env.production?

    payment_status = params["payment_status"]
    booking_id = params["m_payment_id"]
    pf_payment_id = params["pf_payment_id"]

    return unless payment_status == "COMPLETE" && booking_id.present?

    # Find booking
    booking = Booking.find_by(id: booking_id)
    return unless booking

    # Save Payfast payment reference in metadata
    booking.update!(
      metadata: booking.metadata.merge("payfast_payment_id" => pf_payment_id)
    )

    BookingService.payment_succeeded(
      booking: booking,
      stripe_payment_intent_id: pf_payment_id,
      gateway: "payfast"
    )
  end
end
