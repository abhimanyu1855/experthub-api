# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::MatchExpertsService, type: :service do
  let!(:tenant) { create(:tenant) }
  let!(:expert1) { create(:user, :confirmed, given_name: "Ruby", family_name: "Developer") }
  let!(:expert2) { create(:user, :confirmed, given_name: "Python", family_name: "Developer") }

  let!(:profile1) { create(:expert_profile, user: expert1, tenant: tenant, specialization: "Ruby on Rails") }
  let!(:profile2) { create(:expert_profile, user: expert2, tenant: tenant, specialization: "Python Django") }

  before do
    # Create matching embeddings
    # Expert 1 gets vector closer to "Ruby" query
    # We stub OpenAI API call or fallback. 
    # To test actual query mapping, we can stub fetch_query_embedding.
    allow(described_class).to receive(:fetch_query_embedding).and_return(Array.new(1536) { 0.1 })
    
    # Create embeddings in database
    create(:expert_embedding, expert_profile: profile1, embedding: Array.new(1536) { 0.1 })
    create(:expert_embedding, expert_profile: profile2, embedding: Array.new(1536) { -0.1 })
  end

  describe ".match" do
    it "returns matching expert profiles in order of similarity" do
      results = described_class.match(query: "Rails expert", tenant: tenant)
      
      expect(results).to include(profile1)
      expect(results.first).to eq(profile1)
    end
  end
end
