# frozen_string_literal: true

class BookingReminderJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.includes(:client, :expert, :service, :tenant).find_by(id: booking_id)
    return unless booking
    return unless %w[confirmed confirmed_free].include?(booking.aasm_state)

    BookingMailer.session_reminder_to_client(booking).deliver_later
    BookingMailer.session_reminder_to_expert(booking).deliver_later
  end
end
