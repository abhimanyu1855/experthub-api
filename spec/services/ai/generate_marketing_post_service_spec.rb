# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::GenerateMarketingPostService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:expert) { create(:user) }
  let(:client) { create(:user) }
  let(:expert_profile) { create(:expert_profile, user: expert, tenant: tenant) }
  let(:service) { create(:service, expert_profile: expert_profile, tenant: tenant) }
  let(:booking) { create(:booking, service: service, expert: expert, client: client, tenant: tenant) }
  let!(:summary_record) { create(:session_summary, booking: booking, summary: "Discussed scaling, payments drop-off, and customer acquisition.") }

  describe ".generate_post" do
    it "drafts a thought-leadership LinkedIn post from a SessionSummary" do
      post_text = described_class.generate_post(booking: booking)

      expect(post_text).to be_present
      expect(post_text).to include("startup")
      expect(post_text).to include("payment")
    end
  end
end
