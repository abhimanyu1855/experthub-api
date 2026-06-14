# frozen_string_literal: true

# Ported from mytin: scheduled_transaction.rb L173-201 (create_daily_room)
# Replaces raw Net::HTTP with proper client and error handling
class DailyService
  BASE_URL = "https://api.daily.co/v1"

  class DailyError < StandardError; end

  # Create a Daily.co video room for a booking
  # mytin equivalent: ScheduledTransaction#create_daily_room
  def self.create_room(booking)
    room_name = "eh-#{booking.tenant.ident}-#{booking.id}-#{SecureRandom.hex(4)}"

    response = connection.post("/v1/rooms") do |req|
      req.body = {
        name: room_name,
        properties: {
          nbf: booking.start_time.to_i,
          exp: (booking.end_time + 10.minutes).to_i,
          enable_screenshare: true,
          enable_chat: true,
          # TODO: Wire Daily.co transcription webhooks here when the production
          # ingestion path is ready; the manual transcript endpoint covers the MVP.
          start_video_off: false,
          start_audio_off: false,
          max_participants: 10,
          autojoin: true
        },
        privacy: "private"
      }.to_json
    end

    unless response.success?
      raise DailyError, "Failed to create Daily room: #{response.body}"
    end

    data = JSON.parse(response.body)

    booking.create_video_room!(
      provider: "daily",
      url: data["url"],
      provider_room_id: data["id"],
      metadata: { name: data["name"] }
    )

    data["url"]
  end

  # Delete room after booking is completed
  def self.delete_room(room_name)
    connection.delete("/v1/rooms/#{room_name}")
  end

  private

  def self.connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
      f.headers["Authorization"] = "Bearer #{ENV.fetch('DAILY_API_KEY')}"
      f.headers["Content-Type"] = "application/json"
    end
  end
end
