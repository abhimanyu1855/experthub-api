# frozen_string_literal: true

require "rails_helper"

RSpec.describe Review, type: :model do
  let(:tenant) { create(:tenant) }
  let(:reviewer) { create(:user) }
  let(:reviewee) { create(:user) }
  let!(:expert_profile) { create(:expert_profile, user: reviewee, tenant: tenant) }
  let(:service) { create(:service, expert_profile: expert_profile, tenant: tenant) }

  describe "validations" do
    it "requires rating to be between 1 and 5" do
      invalid_review = build(:review, rating: 6, reviewer: reviewer, reviewee: reviewee, reviewable: service, tenant: tenant)
      expect(invalid_review).not_to be_valid

      valid_review = build(:review, rating: 5, reviewer: reviewer, reviewee: reviewee, reviewable: service, tenant: tenant)
      expect(valid_review).to be_valid
    end

    it "requires content to be at least 5 characters" do
      invalid_review = build(:review, content: "bad", reviewer: reviewer, reviewee: reviewee, reviewable: service, tenant: tenant)
      expect(invalid_review).not_to be_valid
    end
  end

  describe "average rating calculations" do
    it "updates the expert's average rating and reviews count on save" do
      expect(expert_profile.reload.average_rating).to eq(0.0)
      expect(expert_profile.reviews_count).to eq(0)

      create(:review, rating: 5, content: "Excellent guide!", reviewer: reviewer, reviewee: reviewee, reviewable: service, tenant: tenant)
      expect(expert_profile.reload.average_rating).to eq(5.0)
      expect(expert_profile.reviews_count).to eq(1)

      another_reviewer = create(:user)
      create(:review, rating: 3, content: "Average session.", reviewer: another_reviewer, reviewee: reviewee, reviewable: service, tenant: tenant)
      expect(expert_profile.reload.average_rating).to eq(4.0)
      expect(expert_profile.reviews_count).to eq(2)
    end
  end
end
