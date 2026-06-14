# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Booking Flow E2E Integration", type: :request do
  let!(:tenant) { create(:tenant) }
  let!(:payment_config) { create(:payment_config, tenant: tenant, gateway: "stripe", encrypted_credentials: "sk_test_123") }
  
  let!(:client_user) { create(:user, :confirmed) }
  let!(:client_membership) { create(:membership, user: client_user, tenant: tenant, role: :client) }

  let!(:expert_user) { create(:user, :confirmed) }
  let!(:expert_membership) { create(:membership, user: expert_user, tenant: tenant, role: :expert) }
  let!(:expert_profile) { create(:expert_profile, user: expert_user, tenant: tenant, approval_status: :approved) }
  let!(:service) { create(:service, expert_profile: expert_profile, tenant: tenant, price_cents: 5000, duration_minutes: 30, slot_interval_minutes: 30) }
  let(:slot_date) { Date.current + 7.days }

  before do
    create(:working_time_slot, expert_profile: expert_profile, week_day: slot_date.cwday, from_time: "09:00", till_time: "11:00")
  end

  describe "Client lifecycle and booking flow" do
    it "performs login, views availability, creates booking, and gets Stripe payload" do
      # 1. Login to retrieve JWT
      post "/login", params: {
        user: {
          email: client_user.email,
          password: "password123"
        }
      }, headers: { "X-Tenant-Id" => tenant.ident }

      expect(response).to have_http_status(:ok)
      auth_token = response.headers["Authorization"]
      expect(auth_token).to be_present

      headers = {
        "Authorization" => auth_token,
        "X-Tenant-Id" => tenant.ident,
        "Accept" => "application/json"
      }

      # 2. Search Experts
      get "/experts", headers: headers
      expect(response).to have_http_status(:ok)
      experts_json = JSON.parse(response.body)
      expect(experts_json.any? { |e| e["email"] == expert_user.email }).to be true

      # 3. View availability slots for the configured future date
      get "/services/#{service.id}/slots", params: { date: slot_date.iso8601 }, headers: headers
      expect(response).to have_http_status(:ok)
      slots_json = JSON.parse(response.body)["slots"]
      expect(slots_json.size).to eq(4)
      expect(slots_json.first["available"]).to be true

      # 4. Book a slot (09:00 - 09:30)
      start_time = "#{slot_date.iso8601}T09:00:00Z"
      end_time = "#{slot_date.iso8601}T09:30:00Z"

      # Stub Stripe call
      intent_double = double(id: "pi_test_123", client_secret: "secret_123", amount: 5000, currency: "usd")
      expect(Stripe::PaymentIntent).to receive(:create) do |params|
        expect(params).not_to have_key(:transfer_data)
        intent_double
      end

      post "/bookings", params: {
        booking: {
          service_id: service.id,
          start_time: start_time,
          end_time: end_time
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      resp = JSON.parse(response.body)
      
      expect(resp["booking"]["aasm_state"]).to eq("payment_initiated")
      expect(resp["payment"]["client_secret"]).to eq("secret_123")
      expect(resp["payment"]["payment_intent_id"]).to eq("pi_test_123")
      expect(resp["payment"]["gateway"]).to eq("stripe")
    end

    it "uses Razorpay for INR bookings when Razorpay is configured" do
      create(:payment_config, tenant: tenant, gateway: "razorpay", publishable_key: "rzp_test_key", encrypted_credentials: "rzp_test_secret")
      service.update!(currency: "INR")

      post "/login", params: {
        user: {
          email: client_user.email,
          password: "password123"
        }
      }, headers: { "X-Tenant-Id" => tenant.ident }

      expect(response).to have_http_status(:ok)
      headers = {
        "Authorization" => response.headers["Authorization"],
        "X-Tenant-Id" => tenant.ident,
        "Accept" => "application/json"
      }

      expect(RazorpayService).to receive(:create_order).and_return(
        order_id: "order_123",
        amount: 5000,
        currency: "INR",
        key_id: "rzp_test_key"
      )
      expect(Stripe::PaymentIntent).not_to receive(:create)

      post "/bookings", params: {
        booking: {
          service_id: service.id,
          start_time: "#{slot_date.iso8601}T09:00:00Z",
          end_time: "#{slot_date.iso8601}T09:30:00Z"
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      resp = JSON.parse(response.body)

      expect(resp["payment"]["gateway"]).to eq("razorpay")
      expect(resp["payment"]["order_id"]).to eq("order_123")
    end
  end
end
