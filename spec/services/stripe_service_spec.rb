# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeService, type: :service do
  let(:tenant) { create(:tenant) }
  let!(:payment_config) { create(:payment_config, tenant: tenant, gateway: "stripe", encrypted_credentials: "sk_test_123") }
  let(:expert) { create(:user, :confirmed) }
  let(:client) { create(:user, :confirmed) }
  let(:expert_profile) { create(:expert_profile, user: expert, tenant: tenant, stripe_account_id: "acct_expert_123") }
  let(:service) { create(:service, expert_profile: expert_profile, tenant: tenant, price_cents: 5000) }

  describe ".create_payment_intent" do
    it "does not attach Connect transfer_data at payment creation time" do
      booking = create(:booking, tenant: tenant, service: service, client: client, expert: expert, price_cents: 5000)
      intent = double(id: "pi_123", client_secret: "secret_123", amount: booking.client_total_cents, currency: "usd")

      expect(Stripe::PaymentIntent).to receive(:create) do |params|
        expect(params).not_to have_key(:transfer_data)
        expect(params[:metadata][:expert_payout_cents]).to eq(booking.expert_payout_cents)
        intent
      end

      result = described_class.create_payment_intent(booking: booking, tenant: tenant)

      expect(result[:payment_intent_id]).to eq("pi_123")
      expect(booking.reload.stripe_payment_intent_id).to eq("pi_123")
    end
  end

  describe ".transfer_to_expert" do
    it "creates exactly one Stripe transfer for the expert payout" do
      booking = create(:booking, tenant: tenant, service: service, client: client, expert: expert, price_cents: 5000, aasm_state: "paid")
      transfer = double(id: "tr_123")

      expect(Stripe::Transfer).to receive(:create).once.with(
        hash_including(
          amount: booking.expert_payout_cents,
          destination: "acct_expert_123",
          transfer_group: "booking_#{booking.id}"
        )
      ).and_return(transfer)

      described_class.transfer_to_expert(booking)
      described_class.transfer_to_expert(booking.reload)

      expect(booking.reload.stripe_transfer_id).to eq("tr_123")
      expect(booking.metadata["payout_status"]).to eq("paid")
    end

    it "marks payout pending when the expert has no connected account" do
      expert_profile.update!(stripe_account_id: nil)
      booking = create(:booking, tenant: tenant, service: service, client: client, expert: expert, price_cents: 5000, aasm_state: "paid")

      expect(Stripe::Transfer).not_to receive(:create)

      described_class.transfer_to_expert(booking)

      expect(booking.reload.stripe_transfer_id).to be_nil
      expect(booking.metadata["payout_status"]).to eq("pending")
      expect(booking.metadata["payout_pending_reason"]).to eq("missing_stripe_account")
    end
  end
end
