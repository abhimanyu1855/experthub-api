# frozen_string_literal: true

class CreateVideoRoomJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    begin
      url = DailyService.create_room(booking)
      Rails.logger.info "Created Daily.co video room for booking ##{booking.id}: #{url}"
    rescue => e
      Rails.logger.error "Error creating Daily.co video room for booking ##{booking.id}: #{e.message}"
    end
  end
end
