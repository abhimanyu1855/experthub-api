# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Booking transcript", type: :request do
  let(:tenant) { create(:tenant, plan: "pro") }
  let(:client) { create(:user, :confirmed) }
  let(:expert) { create(:user, :confirmed) }
  let(:expert_profile) { create(:expert_profile, user: expert, tenant: tenant) }
  let(:service) { create(:service, expert_profile: expert_profile, tenant: tenant) }
  let(:booking) do
    create(
      :booking,
      service: service,
      tenant: tenant,
      client: client,
      expert: expert,
      metadata: { "existing_key" => "keep-me" },
      start_time: 2.hours.ago,
      end_time: 1.hour.ago
    )
  end
  let(:headers) { { "X-Tenant-Id" => tenant.ident } }

  before do
    create(:membership, tenant: tenant, user: client, role: :client)
    create(:membership, tenant: tenant, user: expert, role: :expert)
  end

  it "lets a booking participant attach a transcript and generates a summary for an ended booking" do
    patch "/bookings/#{booking.id}/transcript",
          params: { transcript: "Expert: We reviewed launch risks. Client: I will send metrics.", source: "manual" },
          headers: auth_headers_for(expert)

    expect(response).to have_http_status(:ok)
    expect(booking.reload.metadata).to include(
      "existing_key" => "keep-me",
      "transcript" => "Expert: We reviewed launch risks. Client: I will send metrics.",
      "transcript_source" => "manual"
    )
    expect(booking.session_summary).to be_present

    body = response.parsed_body
    expect(body.dig("session_summary", "summary")).to be_present
    expect(body.dig("session_summary", "action_items")).to be_an(Array)
  end

  it "forbids users who are not the client, expert, or operator" do
    stranger = create(:user, :confirmed)
    create(:membership, tenant: tenant, user: stranger, role: :client)

    patch "/bookings/#{booking.id}/transcript",
          params: { transcript: "Notes from someone else", source: "manual" },
          headers: auth_headers_for(stranger)

    expect(response).to have_http_status(:forbidden)
    expect(booking.reload.metadata).not_to have_key("transcript")
  end

  def auth_headers_for(user)
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    headers.merge("Authorization" => "Bearer #{token}")
  end
end
