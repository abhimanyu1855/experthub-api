# frozen_string_literal: true

class SendBookingReceiptJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.includes(:client, :expert, :service, :tenant).find_by(id: booking_id)
    return unless booking

    BookingMailer.payment_receipt(booking).deliver_now
  end
end
