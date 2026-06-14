# frozen_string_literal: true

class BookingStartedJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    # Mark slot or set active states if needed
    Rails.logger.info "STARTED: Booking ##{booking.id} is now ongoing (start_time: #{booking.start_time})."
  end
end
