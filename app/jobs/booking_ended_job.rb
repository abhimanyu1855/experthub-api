# frozen_string_literal: true

class BookingEndedJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.includes(:client, :expert, :service, :tenant).find_by(id: booking_id)
    return unless booking

    # Generate AI session summary if the tenant's plan includes it.
    if booking.tenant.feature_allowed?(:session_summaries)
      transcript = booking.metadata&.dig("transcript")
      if transcript.present?
        Ai::GenerateSummaryService.summarize(booking: booking, transcript: transcript)
      else
        Rails.logger.info "ENDED: Skipping AI session summary for booking ##{booking.id} because no transcript is attached"
      end
    else
      Rails.logger.info "ENDED: Skipping AI session summary for booking ##{booking.id} because tenant ##{booking.tenant_id} does not allow session_summaries"
    end

    # Send booking completed emails
    begin
      BookingMailer.booking_completed_to_client(booking).deliver_later
      BookingMailer.booking_completed_to_expert(booking).deliver_later
    rescue => e
      Rails.logger.error "Failed to send booking completed emails for booking ##{booking.id}: #{e.message}"
    end

    Rails.logger.info "ENDED: Processed post-session tasks for booking ##{booking.id}"
  end
end
