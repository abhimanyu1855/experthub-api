# frozen_string_literal: true

class ConfirmBookingJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    BookingService.auto_confirm(booking)
  end
end
