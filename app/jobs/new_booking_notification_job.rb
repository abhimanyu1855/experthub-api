# frozen_string_literal: true

class NewBookingNotificationJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.includes(:client, :expert, :service, :tenant).find_by(id: booking_id)
    return unless booking

    BookingMailer.new_booking_alert(booking).deliver_now
  end
end
