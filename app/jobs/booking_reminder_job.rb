# frozen_string_literal: true

class BookingReminderJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.includes(:client, :expert, :service, :tenant).find_by(id: booking_id)
    return unless booking
    return unless booking.confirmed?

    BookingMailer.session_reminder(booking).deliver_now
  end
end
