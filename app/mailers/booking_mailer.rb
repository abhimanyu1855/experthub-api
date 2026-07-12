# frozen_string_literal: true

class BookingMailer < ApplicationMailer
  # Receipt to client after payment succeeds
  def payment_receipt(booking)
    @booking = booking
    @client = booking.client
    @expert = booking.expert
    @service = booking.service
    @tenant = booking.tenant

    mail(
      to: @client.email,
      subject: "Your booking confirmation — #{@service.title}"
    )
  end

  # New booking alert to expert
  def new_booking_alert(booking)
    @booking = booking
    @client = booking.client
    @expert = booking.expert
    @service = booking.service
    @tenant = booking.tenant

    mail(
      to: @expert.email,
      subject: "New booking: #{@service.title} with #{@client.displayed_name}"
    )
  end

  # Reminder 10 minutes before session starts (client)
  def session_reminder_to_client(booking)
    @booking = booking
    @client = booking.client
    @expert = booking.expert
    @service = booking.service
    @tenant = booking.tenant

    mail(
      to: @client.email,
      subject: "Your session starts soon — #{@service.title}"
    )
  end

  # Reminder 10 minutes before session starts (expert)
  def session_reminder_to_expert(booking)
    @booking = booking
    @client = booking.client
    @expert = booking.expert
    @service = booking.service
    @tenant = booking.tenant

    mail(
      to: @expert.email,
      subject: "Upcoming session in 10 minutes — #{@service.title}"
    )
  end

  # Session completion notice to client
  def booking_completed_to_client(booking)
    @booking = booking
    @client = booking.client
    @expert = booking.expert
    @service = booking.service
    @tenant = booking.tenant

    mail(
      to: @client.email,
      subject: "How was your session with #{@expert.displayed_name}?"
    )
  end

  # Session completion notice to expert
  def booking_completed_to_expert(booking)
    @booking = booking
    @client = booking.client
    @expert = booking.expert
    @service = booking.service
    @tenant = booking.tenant

    mail(
      to: @expert.email,
      subject: "Session completed: #{@service.title} with #{@client.displayed_name}"
    )
  end
end
