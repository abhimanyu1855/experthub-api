# frozen_string_literal: true

class SessionSummaryMailer < ApplicationMailer
  def summary_email(booking, recipient)
    @booking = booking
    @recipient = recipient
    @client = booking.client
    @expert = booking.expert
    @summary = booking.session_summary
    @tenant = booking.tenant

    mail(
      to: @recipient.email,
      subject: "Session Summary & Action Items — #{@booking.service.title}"
    )
  end
end
