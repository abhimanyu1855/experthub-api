# frozen_string_literal: true

class SendWebhookJob < ApplicationJob
  queue_as :default

  def perform(booking_id, event_type)
    booking = Booking.includes(:service, :client, :expert, :tenant).find_by(id: booking_id)
    return unless booking

    tenant = booking.tenant
    webhook_url = tenant.settings&.dig("webhook_url")
    return unless webhook_url.present?

    payload = {
      event: event_type,
      booking_id: booking.id,
      service: booking.service&.title,
      client_email: booking.client&.email,
      expert_email: booking.expert&.email,
      start_time: booking.start_time&.iso8601,
      amount_cents: booking.client_total_cents,
      currency: booking.currency,
      status: booking.aasm_state
    }

    conn = Faraday.new do |f|
      f.request :json
      f.options.timeout = 10
    end

    response = conn.post(webhook_url) do |req|
      req.headers["X-ExpertHub-Event"] = event_type
      req.headers["X-ExpertHub-Tenant"] = tenant.ident
      req.body = payload
    end

    Rails.logger.info "Webhook #{event_type} delivered to #{webhook_url}: #{response.status}"
  rescue => e
    Rails.logger.error "Webhook delivery failed for #{event_type}: #{e.message}"
    raise # allow Solid Queue to retry
  end
end
