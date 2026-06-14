# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommissionCalculator, type: :service do
  let(:tenant) { create(:tenant, seller_commission_pct: 10.0, buyer_commission_pct: 2.0, minimum_commission_cents: 150) }
  let(:service) { create(:service, price_cents: 2000, tenant: tenant) }
  let(:booking) { build(:booking, service: service, price_cents: 2000, tenant: tenant) }

  describe ".calculate" do
    it "calculates standard percentages when above minimum floor" do
      result = described_class.calculate(booking)

      # 10% of 2000 is 200 (which is > 150 floor)
      expect(result[:commission_cents]).to eq(200)
      # 2% of 2000 is 40
      expect(result[:buyer_fee_cents]).to eq(40)
      # payout = 2000 - 200 = 1800
      expect(result[:expert_payout_cents]).to eq(1800)
    end

    it "enforces minimum commission floor" do
      booking.price_cents = 1000 # $10 booking
      result = described_class.calculate(booking)

      # 10% of 1000 is 100, which is below 150 floor, so it should be bumped to 150
      expect(result[:commission_cents]).to eq(150)
      expect(result[:expert_payout_cents]).to eq(850)
    end

    it "uses flat fee commission model if set in tenant settings" do
      tenant.settings = { "commission_model" => "flat", "commission_flat_fee_cents" => 350 }
      result = described_class.calculate(booking)

      expect(result[:commission_cents]).to eq(350)
      expect(result[:expert_payout_cents]).to eq(1650)
    end

    it "enforces maximum commission cap if set in tenant settings" do
      tenant.settings = { "commission_model" => "percentage", "max_commission_cents" => 500 }
      # 10% of 2000 is 200, which is below 500 cap
      result = described_class.calculate(booking)
      expect(result[:commission_cents]).to eq(200)

      # set price higher: $100.00 booking
      booking.price_cents = 10000
      # 10% of 10000 is 1000, which is above 500 cap, so it should be capped to 500
      result = described_class.calculate(booking)
      expect(result[:commission_cents]).to eq(500)
      expect(result[:expert_payout_cents]).to eq(9500)
    end
  end
end
