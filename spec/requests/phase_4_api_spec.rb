# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Phase 4 API Endpoints", type: :request do
  let!(:tenant) { create(:tenant, settings: { "referral_reward_cents" => 1000 }) }
  let!(:payment_config) { create(:payment_config, tenant: tenant, gateway: "stripe") }

  let!(:referrer_user) { create(:user, :confirmed) }
  let!(:referrer_membership) { create(:membership, user: referrer_user, tenant: tenant, role: :client) }

  let!(:client_user) { create(:user, :confirmed) }
  let!(:client_membership) { create(:membership, user: client_user, tenant: tenant, role: :client) }

  let!(:expert_user) { create(:user, :confirmed) }
  let!(:expert_membership) { create(:membership, user: expert_user, tenant: tenant, role: :expert) }
  let!(:expert_profile) { create(:expert_profile, user: expert_user, tenant: tenant) }
  let!(:service) { create(:service, expert_profile: expert_profile, tenant: tenant, price_cents: 5000) }

  let!(:operator_user) { create(:user, :confirmed) }
  let!(:operator_membership) { create(:membership, user: operator_user, tenant: tenant, role: :operator) }


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

  describe "Referrals Flow API" do
    it "processes referred client registration, rewards both, and applies discount on next booking" do
      # 1. Sign up referred client
      post "/signup", params: {
        user: {
          email: "referred_client@example.com",
          password: "password123",
          password_confirmation: "password123",
          given_name: "Referred",
          family_name: "User",
          referred_by_code: referrer_user.referral_code
        },
        role: "client"
      }, headers: { "X-Tenant-Id" => tenant.ident }

      expect(response).to have_http_status(:ok)
      signup_json = JSON.parse(response.body)
      client_id = signup_json.dig("data", "id")
      client = User.find(client_id)

      expect(client.referred_by_code).to eq(referrer_user.referral_code)

      # Log in as client
      client_headers = auth_headers(client)

      # Retrieve referrals summary (should show referral code, 0 referrals, and 0 credits)
      get "/referrals/summary", headers: client_headers
      expect(response).to have_http_status(:ok)
      summary_json = JSON.parse(response.body)
      expect(summary_json["referral_code"]).to eq(client.referral_code)
      expect(summary_json["active_credits_cents"]).to eq(0)

      # 2. Complete first booking (causes payment_succeeded)
      booking = BookingService.create(
        service: service,
        client: client,
        start_time: Time.current + 2.hours,
        end_time: Time.current + 3.hours,
        tenant: tenant
      )

      # Check that discount_cents was 0 for first booking
      expect(booking.discount_cents).to eq(0)

      # Complete payment
      BookingService.payment_succeeded(booking: booking, stripe_payment_intent_id: "pi_first")

      # Both users should receive 1000 cents referral credit reward!
      expect(referrer_user.referral_credits.active.sum(:amount_cents)).to eq(1000)
      expect(client.referral_credits.active.sum(:amount_cents)).to eq(1000)

      # Check client's referrals summary now
      get "/referrals/summary", headers: client_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["active_credits_cents"]).to eq(1000)

      # 3. Create second booking (referral credits should be applied as discount)
      booking2 = BookingService.create(
        service: service,
        client: client,
        start_time: Time.current + 24.hours,
        end_time: Time.current + 25.hours,
        tenant: tenant
      )

      expect(booking2.discount_cents).to eq(1000)
      expect(booking2.client_total_cents).to eq(4000) # 5000 price - 1000 discount

      # Payment succeeds for booking2
      BookingService.payment_succeeded(booking: booking2, stripe_payment_intent_id: "pi_second")

      # Client's credits should be redeemed
      expect(client.referral_credits.active.sum(:amount_cents)).to eq(0)
    end
  end

  describe "i18n Localization API" do
    let!(:category) do
      create(:category,
        tenant: tenant,
        name: "Software Consulting",
        translations: { "es" => "Consultoría de Software" }
      )
    end
    let!(:service_with_cat) { create(:service, expert_profile: expert_profile, tenant: tenant, category: category) }

    it "uses Accept-Language header to return localized category details" do
      tenant.update!(supported_locales: ["en", "es"])

      # Query in English (default)
      get "/services", headers: { "X-Tenant-Id" => tenant.ident }
      expect(response).to have_http_status(:ok)
      services = JSON.parse(response.body)
      service_json = services.find { |s| s["id"] == service_with_cat.id }
      expect(service_json.dig("category", "name")).to eq("Software Consulting")

      # Query in Spanish
      get "/services", headers: { "X-Tenant-Id" => tenant.ident, "Accept-Language" => "es" }
      expect(response).to have_http_status(:ok)
      services = JSON.parse(response.body)
      service_json = services.find { |s| s["id"] == service_with_cat.id }
      expect(service_json.dig("category", "name")).to eq("Consultoría de Software")
    end
  end



  describe "Payment Webhooks API (PayPal & Payfast)" do
    let!(:booking) do
      create(:booking,
        tenant: tenant,
        service: service,
        client: client_user,
        expert: expert_user,
        aasm_state: "payment_initiated",
        metadata: { "paypal_order_id" => "ORDER-12345" }
      )
    end

    it "handles PayPal capture webhook events" do
      paypal_payload = {
        id: "evt_paypal_test",
        event_type: "PAYMENT.CAPTURE.COMPLETED",
        resource: {
          id: "ORDER-12345",
          status: "COMPLETED"
        }
      }.to_json

      post "/webhooks/paypal", params: paypal_payload, headers: {
        "X-Tenant-Id" => tenant.ident,
        "CONTENT_TYPE" => "application/json"
      }
      expect(response).to have_http_status(:ok)

      booking.reload
      expect(booking.aasm_state).to eq("paid")
      expect(booking.payment_records.first.gateway).to eq("paypal")
    end

    it "handles Payfast ITN callback notifications" do
      payfast_params = {
        m_payment_id: booking.id.to_s,

        pf_payment_id: "PAYFAST-998877",
        payment_status: "COMPLETE",
        amount_gross: "50.00"
      }

      post "/webhooks/payfast", params: payfast_params, headers: { "X-Tenant-Id" => tenant.ident }
      expect(response).to have_http_status(:ok)

      booking.reload
      expect(booking.aasm_state).to eq("paid")
      expect(booking.metadata["payfast_payment_id"]).to eq("PAYFAST-998877")
      expect(booking.payment_records.first.gateway).to eq("payfast")
    end
  end

  describe "Analytics Dashboards API" do
    let!(:booking) do
      create(:booking,
        tenant: tenant,
        service: service,
        client: client_user,
        expert: expert_user,
        aasm_state: "paid",
        price_cents: 5000,
        commission_cents: 750,
        expert_payout_cents: 4250
      )
    end

    it "returns correct operator and expert reports" do
      # Retrieve operator dashboard reports
      operator_headers = auth_headers(operator_user)
      get "/analytics/dashboard", headers: operator_headers
      expect(response).to have_http_status(:ok)
      dash_json = JSON.parse(response.body)
      expect(dash_json["total_sales_cents"]).to eq(5000)
      expect(dash_json["total_commission_cents"]).to eq(750)
      expect(dash_json["total_bookings_count"]).to eq(1)

      # Retrieve expert dashboard reports
      expert_headers = auth_headers(expert_user)
      get "/analytics/expert", headers: expert_headers
      expect(response).to have_http_status(:ok)
      exp_json = JSON.parse(response.body)
      expect(exp_json["expert_bookings_count"]).to eq(1)
      expect(exp_json["expert_sales_cents"]).to eq(5000)
      expect(exp_json["expert_payout_cents"]).to eq(4250)
    end

    it "blocks clients from viewing operator dashboard" do
      client_headers = auth_headers(client_user)
      get "/analytics/dashboard", headers: client_headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
