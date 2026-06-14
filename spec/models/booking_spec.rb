# frozen_string_literal: true

require "rails_helper"

RSpec.describe Booking, type: :model do
  describe "validations" do
    it "validates that end_time is after start_time" do
      booking = build(:booking, start_time: Time.current + 1.hour, end_time: Time.current)
      expect(booking).not_to be_valid
      expect(booking.errors[:end_time]).to include("must be after start time")
    end

    it "prevents overlapping confirmed/paid bookings for the same expert" do
      existing = create(:booking, start_time: Time.current + 1.hour, end_time: Time.current + 2.hours, aasm_state: "paid")
      
      # Overlap at start
      overlap = build(:booking, service: existing.service, client: existing.client, start_time: Time.current + 30.minutes, end_time: Time.current + 90.minutes)
      expect(overlap).not_to be_valid
      expect(overlap.errors[:base]).to include("Expert has a conflicting booking at this time")
    end

    it "allows overlapping bookings if the existing booking is pending or canceled" do
      existing = create(:booking, start_time: Time.current + 1.hour, end_time: Time.current + 2.hours, aasm_state: "pending")
      
      overlap = build(:booking, service: existing.service, client: existing.client, start_time: Time.current + 30.minutes, end_time: Time.current + 90.minutes)
      expect(overlap).to be_valid
    end
  end

  describe "state machine transitions" do
    let(:booking) { create(:booking, aasm_state: "pending") }

    it "transitions through standard paid flow" do
      expect(booking.aasm_state).to eq("pending")
      
      booking.initiate_payment!
      expect(booking.aasm_state).to eq("payment_initiated")

      booking.authorize_payment!
      expect(booking.aasm_state).to eq("authorized")

      booking.mark_paid!
      expect(booking.aasm_state).to eq("paid")

      booking.confirm!
      expect(booking.aasm_state).to eq("confirmed")
    end

    it "allows free bookings to bypass payment" do
      booking.confirm_free!
      expect(booking.aasm_state).to eq("confirmed_free")
    end
  end

  describe "commission calculations" do
    let(:tenant) { create(:tenant, seller_commission_pct: 20.0, buyer_commission_pct: 5.0, minimum_commission_cents: 200) }
    let(:service) { create(:service, price_cents: 1000, tenant: tenant) } # $10 booking

    it "calculates correct commission values upon creation" do
      booking = create(:booking, service: service, price_cents: 1000, tenant: tenant)
      
      # 20% of 1000 is 200 cents (equals min_commission of 200)
      expect(booking.commission_cents).to eq(200)
      # 5% of 1000 is 50 cents
      expect(booking.buyer_fee_cents).to eq(50)
      # payout is price - commission = 1000 - 200 = 800
      expect(booking.expert_payout_cents).to eq(800)
      # total client pays is price + buyer_fee = 1000 + 50 = 1050
      expect(booking.client_total_cents).to eq(1050)
    end

    it "enforces minimum commission cents" do
      low_price_service = create(:service, price_cents: 500, tenant: tenant) # $5 booking
      booking = create(:booking, service: low_price_service, price_cents: 500, tenant: tenant)
      
      # 20% of 500 is 100 cents, but minimum is 200
      expect(booking.commission_cents).to eq(200)
      expect(booking.expert_payout_cents).to eq(300)
    end
  end
end
