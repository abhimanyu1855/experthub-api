# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::GenerateSummaryService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:expert) { create(:user) }
  let(:client) { create(:user) }
  let(:expert_profile) { create(:expert_profile, user: expert, tenant: tenant) }
  let(:service) { create(:service, expert_profile: expert_profile, tenant: tenant) }
  let(:booking) { create(:booking, service: service, expert: expert, client: client, tenant: tenant) }

  describe ".summarize" do
    it "processes raw transcript text and creates a SessionSummary" do
      transcript = "Expert: Let's design the schema. Client: Yes, we need a booking table."
      
      summary = described_class.summarize(
        booking: booking,
        transcript: transcript
      )

      expect(summary).to be_present
      expect(summary.booking).to eq(booking)
      expect(summary.summary).to be_present
      expect(summary.action_items).to be_an(Array)
      expect(summary.action_items.first["description"]).to be_present
    end
  end
end
