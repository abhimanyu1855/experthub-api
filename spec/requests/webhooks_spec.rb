# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stripe Webhooks API", type: :request do
  let(:tenant) { create(:tenant) }
  let!(:payment_config) { create(:payment_config, tenant: tenant, gateway: "stripe", encrypted_credentials: "sk_test_123") }
  let!(:booking) { create(:booking, tenant: tenant, price_cents: 1000, aasm_state: "payment_initiated", stripe_payment_intent_id: "pi_test_123") }

  describe "POST /webhooks/stripe" do
    it "processes payment succeeded webhook and marks booking as paid" do
      payload = {
        id: "evt_test_123",
        type: "payment_intent.succeeded",
        data: {
          object: {
            id: "pi_test_123",
            amount: 1000,
            status: "succeeded"
          }
        }
      }.to_json

      headers = {
        "X-Tenant-Id" => tenant.ident,
        "CONTENT_TYPE" => "application/json"
      }

      post "/webhooks/stripe", params: payload, headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ "received" => true })

      booking.reload
      expect(booking.aasm_state).to eq("paid")
      expect(booking.payment_records.count).to eq(1)
      expect(booking.payment_records.first.status).to eq("succeeded")
    end

    it "handles failed payments" do
      payload = {
        id: "evt_test_124",
        type: "payment_intent.payment_failed",
        data: {
          object: {
            id: "pi_test_123",
            status: "requires_payment_method"
          }
        }
      }.to_json

      headers = {
        "X-Tenant-Id" => tenant.ident,
        "CONTENT_TYPE" => "application/json"
      }

      post "/webhooks/stripe", params: payload, headers: headers

      expect(response).to have_http_status(:ok)
      
      booking.reload
      expect(booking.aasm_state).to eq("payment_failed")
    end

    it "ignores duplicate events (idempotency check)" do
      payload = {
        id: "evt_duplicate_123",
        type: "payment_intent.succeeded",
        data: {
          object: {
            id: "pi_test_123",
            amount: 1000,
            status: "succeeded"
          }
        }
      }.to_json

      headers = {
        "X-Tenant-Id" => tenant.ident,
        "CONTENT_TYPE" => "application/json"
      }

      # First call
      post "/webhooks/stripe", params: payload, headers: headers
      expect(response).to have_http_status(:ok)

      # Reset state to test duplication logic
      booking.reload
      booking.update!(aasm_state: "payment_initiated")

      # Second call
      post "/webhooks/stripe", params: payload, headers: headers
      expect(response).to have_http_status(:ok)
      
      # Booking remains payment_initiated because duplicate event is ignored
      expect(booking.reload.aasm_state).to eq("payment_initiated")
    end

    it "rejects unsigned production webhooks when no Stripe webhook secret is configured" do
      allow(Rails.env).to receive(:production?).and_return(true)

      payload = {
        id: "evt_unsigned_prod",
        type: "payment_intent.succeeded",
        data: {
          object: {
            id: "pi_test_123",
            amount: 1000,
            status: "succeeded"
          }
        }
      }.to_json

      post "/webhooks/stripe",
           params: payload,
           headers: {
             "X-Tenant-Id" => tenant.ident,
             "CONTENT_TYPE" => "application/json"
           }

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["error"]).to include("signature verification is required")
      expect(booking.reload.aasm_state).to eq("payment_initiated")
    end
  end

  describe "POST /webhooks/razorpay" do
    it "rejects unsigned production webhooks when no Razorpay webhook secret is configured" do
      create(:payment_config, tenant: tenant, gateway: "razorpay", publishable_key: "rzp_test_key", encrypted_credentials: "rzp_test_secret")
      allow(Rails.env).to receive(:production?).and_return(true)

      payload = {
        id: "evt_razorpay_unsigned",
        event: "payment.captured",
        payload: {
          payment: {
            entity: {
              id: "pay_123",
              order_id: "order_123",
              amount: 1000
            }
          }
        }
      }.to_json

      post "/webhooks/razorpay",
           params: payload,
           headers: {
             "X-Tenant-Id" => tenant.ident,
             "CONTENT_TYPE" => "application/json"
           }

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["error"]).to include("signature verification is required")
    end
  end
end
