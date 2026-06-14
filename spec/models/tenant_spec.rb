# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tenant, type: :model do
  describe "validations" do
    subject { build(:tenant) }

    it { should validate_presence_of(:ident) }
    it { should validate_uniqueness_of(:ident) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:default_currency) }

    it "validates that ident is alphanumeric with optional hyphens" do
      valid_tenant = build(:tenant, ident: "my-tenant-1")
      expect(valid_tenant).to be_valid

      invalid_tenant = build(:tenant, ident: "My_tenant!")
      expect(invalid_tenant).not_to be_valid
    end

    it "prevents reserved subdomains from being used as ident" do
      reserved_tenant = build(:tenant, ident: "admin")
      expect(reserved_tenant).not_to be_valid
      expect(reserved_tenant.errors[:ident]).to include("is reserved")
    end
  end

  describe "settings" do
    let(:tenant) { create(:tenant, settings: { "booking_buffer_minutes" => 45, "auto_confirm_bookings" => true }) }

    it "retrieves settings by key" do
      expect(tenant.booking_buffer_minutes).to eq(45)
      expect(tenant.auto_confirm_bookings?).to be true
    end

    it "returns default when settings key is missing" do
      empty_tenant = create(:tenant, settings: {})
      expect(empty_tenant.booking_buffer_minutes).to eq(0)
      expect(empty_tenant.auto_confirm_bookings?).to be false
    end
  end

  describe "plan features" do
    it "gives trial tenants pro-level demo features" do
      tenant = build(:tenant, plan: "trial")

      expect(tenant.feature_allowed?(:ai_matching)).to be true
      expect(tenant.feature_allowed?(:triage_chatbot)).to be true
      expect(tenant.feature_allowed?(:session_summaries)).to be true
      expect(tenant.feature_allowed?(:courses)).to be true
      expect(tenant.feature_allowed?(:group_sessions)).to be true
      expect(tenant.feature_allowed?(:promo_codes)).to be true
      expect(tenant.feature_allowed?(:subscriptions)).to be true
      expect(tenant.feature_allowed?(:booking_packages)).to be true
      expect(tenant.feature_allowed?(:webhooks)).to be true
      expect(tenant.feature_allowed?(:advanced_analytics)).to be true
      expect(tenant.plan_features[:max_experts]).to eq(25)
    end
  end
end
