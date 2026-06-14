# frozen_string_literal: true

require "rails_helper"

RSpec.describe RazorpayService, type: :service do
  let(:tenant) { create(:tenant) }
  let!(:payment_config) { create(:payment_config, tenant: tenant, gateway: "razorpay", publishable_key: "rzp_test_key", encrypted_credentials: "rzp_test_secret") }
  
  let(:client) { create(:user, :confirmed) }
  let(:expert) { create(:user, :confirmed) }
  let(:expert_profile) { create(:expert_profile, user: expert, tenant: tenant) }
  let(:service) { create(:service, expert_profile: expert_profile, tenant: tenant, price_cents: 5000) }
  
  let!(:booking) do
    create(:booking,
      tenant: tenant,
      service: service,
      client: client,
      expert: expert,
      price_cents: 5000,
      aasm_state: "payment_initiated",
      metadata: {}
    )
  end

  describe ".create_order" do
    it "calls Razorpay API to create an order and updates booking metadata" do
      # Stub Faraday request
      response_double = double(success?: true, body: { "id" => "order_12345" })
      expect_any_instance_of(Faraday::Connection).to receive(:post).and_return(response_double)

      res = described_class.create_order(booking: booking, tenant: tenant)
      
      expect(res[:order_id]).to eq("order_12345")
      expect(booking.reload.metadata["razorpay_order_id"]).to eq("order_12345")
    end
  end

  describe ".transfer_to_expert" do
    let!(:payout_account) { create(:payout_account, expert_profile: expert_profile, gateway: "razorpay", account_identifier: "acc_expert_123") }
    let!(:payment_record) { create(:payment_record, booking: booking, gateway: "razorpay", provider_id: "pay_12345", status: "succeeded") }

    before do
      booking.update!(metadata: { "razorpay_order_id" => "order_12345" })
    end

    it "calls Razorpay Route API to transfer the expert payout portion" do
      response_double = double(success?: true, body: { "items" => [{ "id" => "trf_123" }] })
      expect_any_instance_of(Faraday::Connection).to receive(:post).and_return(response_double)

      described_class.transfer_to_expert(booking)

      expect(booking.reload.metadata["razorpay_transfer_id"]).to eq("trf_123")
    end
  end

  describe ".handle_webhook" do
    before do
      booking.update!(metadata: { "razorpay_order_id" => "order_12345" })
    end

    it "processes payment.captured event, creates payment record and marks booking as paid" do
      payload = {
        event: "payment.captured",
        payload: {
          payment: {
            entity: {
              id: "pay_captured_123",
              order_id: "order_12345",
              amount: 5000,
              status: "captured"
            }
          }
        }
      }.to_json

      # signature is optional in tests if secret is not set, or we stub verification
      allow(described_class).to receive(:verify_signature!).and_return(true)

      described_class.handle_webhook(payload: payload, signature: "sig", tenant: tenant)

      booking.reload
      expect(booking.aasm_state).to eq("paid")
      expect(booking.payment_records.count).to eq(1)
      expect(booking.payment_records.first.provider_id).to eq("pay_captured_123")
    end
  end
end
