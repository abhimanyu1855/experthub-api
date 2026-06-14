# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Phase 2 API Endpoints", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:payment_config) { create(:payment_config, tenant: tenant, gateway: "stripe", encrypted_credentials: "sk_test_123") }
  
  let!(:client_user) { create(:user, :confirmed) }
  let!(:client_membership) { create(:membership, user: client_user, tenant: tenant, role: :client) }

  let!(:expert_user) { create(:user, :confirmed) }
  let!(:expert_membership) { create(:membership, user: expert_user, tenant: tenant, role: :expert) }
  let!(:expert_profile) { create(:expert_profile, user: expert_user, tenant: tenant) }
  let!(:service) { create(:service, expert_profile: expert_profile, tenant: tenant) }

  let!(:booking) do
    create(:booking,
      tenant: tenant,
      service: service,
      client: client_user,
      expert: expert_user,
      aasm_state: "confirmed"
    )
  end

  # Helper to generate authenticated headers
  def auth_headers(user)
    post "/login", params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }, headers: { "X-Tenant-Id" => tenant.ident }

    expect(response).to have_http_status(:ok)
    auth_token = response.headers["Authorization"]
    {
      "Authorization" => auth_token,
      "X-Tenant-Id" => tenant.ident,
      "Accept" => "application/json"
    }
  end

  describe "Reviews API" do
    it "creates and fetches reviews" do
      headers = auth_headers(client_user)

      post "/services/#{service.id}/reviews", params: {
        review: {
          rating: 4,
          content: "Great service, learned a lot!"
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["rating"]).to eq(4)

      # Fetch reviews (public endpoint, no auth required)
      get "/services/#{service.id}/reviews", headers: { "X-Tenant-Id" => tenant.ident }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end
  end

  describe "Rescheduling API" do
    it "requests a reschedule and allows the other party to accept it" do
      headers_client = auth_headers(client_user)

      # Request reschedule
      post "/bookings/#{booking.id}/reschedule_requests", params: {
        reschedule_request: {
          new_start_time: (Time.current + 24.hours).iso8601,
          new_end_time: (Time.current + 25.hours).iso8601,
          reason: "Prior conflict"
        }
      }, headers: headers_client

      expect(response).to have_http_status(:created)
      req_json = JSON.parse(response.body)
      expect(req_json["status"]).to eq("pending")

      # Log in as expert to accept
      headers_expert = auth_headers(expert_user)
      post "/reschedule_requests/#{req_json["id"]}/accept", headers: headers_expert

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["status"]).to eq("accepted")

      booking.reload
      expect(booking.start_time.to_date).to eq((Time.current + 24.hours).to_date)
    end
  end

  describe "Chat API" do
    it "manages conversations and message routing" do
      headers = auth_headers(client_user)

      # Create conversation
      post "/conversations", params: { recipient_id: expert_user.id }, headers: headers
      expect(response).to have_http_status(:created)
      conv_json = JSON.parse(response.body)
      expect(conv_json["id"]).to be_present

      # Send a message
      post "/conversations/#{conv_json["id"]}/messages", params: {
        message: { content: "Hello expert!" }
      }, headers: headers
      expect(response).to have_http_status(:created)

      # Fetch messages
      get "/conversations/#{conv_json["id"]}/messages", headers: headers
      expect(response).to have_http_status(:ok)
      messages_json = JSON.parse(response.body)
      expect(messages_json.size).to eq(1)
      expect(messages_json.first["content"]).to eq("Hello expert!")
    end
  end

  describe "Notifications API" do
    let!(:notification) { create(:notification, tenant: tenant, user: client_user) }

    it "lists and reads notifications" do
      headers = auth_headers(client_user)

      # List notifications
      get "/notifications", headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)

      # Read notification
      post "/notifications/#{notification.id}/read", headers: headers
      expect(response).to have_http_status(:ok)

      # List again (should be 0 unread)
      get "/notifications", headers: headers
      expect(JSON.parse(response.body).size).to eq(0)
    end
  end

  describe "AI Match & Triage API" do
    let!(:category) { create(:category, tenant: tenant, name: "Consulting", slug: "consulting") }
    let!(:embedding) { create(:expert_embedding, expert_profile: expert_profile) }

    it "finds matching experts" do
      headers = { "X-Tenant-Id" => tenant.ident }
      
      # Mock the pgvector similarity results
      allow(Ai::MatchExpertsService).to receive(:match).and_return([expert_profile])

      post "/ai/match", params: { query: "I need consulting advice" }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end

    it "creates a triage chat session and exchanges messages" do
      headers = { "X-Tenant-Id" => tenant.ident }

      # Create triage session
      post "/ai/triage_sessions", headers: headers
      expect(response).to have_http_status(:created)
      session_json = JSON.parse(response.body)
      token = session_json["session_token"]
      expect(token).to be_present

      # Chat in session
      post "/ai/triage_sessions/#{token}/chat", params: { message: "I want a Consulting expert" }, headers: headers
      expect(response).to have_http_status(:ok)
      chat_json = JSON.parse(response.body)
      expect(chat_json["reply"]).to be_present
      expect(chat_json["recommendations"]["category_slugs"]).to include("consulting")
    end
  end
end
