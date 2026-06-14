# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::TriageChatService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user) }
  let!(:category) { create(:category, tenant: tenant, name: "Web Development", slug: "web-development") }
  
  let(:session) do
    create(:ai_triage_session,
      tenant: tenant,
      user: user,
      messages: [{ role: "assistant", content: "How can I help you?" }]
    )
  end

  describe ".send_message" do
    it "appends user message and gets assistant reply with recommendations" do
      result = described_class.send_message(
        session: session,
        content: "I need help with Web Development."
      )

      expect(result[:reply]).to include("web-development")
      expect(result[:status]).to eq("triaged")
      expect(result[:recommendations]["category_slugs"]).to include("web-development")

      session.reload
      expect(session.messages.size).to eq(3) # assistant -> user -> assistant
      expect(session.status).to eq("triaged")
    end
  end
end
