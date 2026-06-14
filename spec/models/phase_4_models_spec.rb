# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Phase 4 Models", type: :model do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user) }

  describe User do
    it "automatically generates a unique referral code on creation" do
      user1 = create(:user)
      user2 = create(:user)

      expect(user1.referral_code).to start_with("EH-")
      expect(user1.referral_code.length).to eq(9) # EH- + 6 characters
      expect(user1.referral_code).not_to eq(user2.referral_code)
    end
  end

  describe ReferralCredit do
    it "validates presence and numericality of amount" do
      credit = build(:referral_credit, amount_cents: 0, tenant: tenant, user: user)
      expect(credit).not_to be_valid

      credit = build(:referral_credit, amount_cents: 1000, tenant: tenant, user: user)
      expect(credit).to be_valid
    end

    it "validates status inclusion" do
      credit = build(:referral_credit, status: "pending", tenant: tenant, user: user)
      expect(credit).not_to be_valid
    end

    it "supports redeeming credits" do
      credit = create(:referral_credit, amount_cents: 1000, status: "active", tenant: tenant, user: user)
      credit.redeem!
      expect(credit.reload.status).to eq("redeemed")
    end
  end

  describe "Localizable Concern" do
    let!(:category) do
      create(:category,
        tenant: tenant,
        name: "Software Consulting",
        translations: { "es" => "Consultoría de Software", "fr" => "Conseil en Logiciel" }
      )
    end

    it "returns localized attributes based on current I18n.locale" do
      expect(category.name).to eq("Software Consulting") # defaults to DB column when locale is en

      I18n.with_locale(:es) do
        expect(category.name).to eq("Consultoría de Software")
      end

      I18n.with_locale(:fr) do
        expect(category.name).to eq("Conseil en Logiciel")
      end
    end

    it "falls back to the default column name if translation is missing for the locale" do
      I18n.with_locale(:de) do
        expect(category.name).to eq("Software Consulting")
      end
    end
  end
end
