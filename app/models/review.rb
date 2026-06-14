# frozen_string_literal: true

class Review < ApplicationRecord
  belongs_to :tenant
  belongs_to :reviewer, class_name: "User"
  belongs_to :reviewee, class_name: "User", optional: true
  belongs_to :reviewable, polymorphic: true

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :content, presence: true, length: { minimum: 5 }

  after_commit :update_expert_rating, on: [:create, :update, :destroy]

  private

  def update_expert_rating
    return unless reviewee_id.present?
    
    expert_profile = User.find_by(id: reviewee_id)&.expert_profile
    return unless expert_profile

    # Calculate average rating and count
    avg_rating, rating_count = Review.where(reviewee_id: reviewee_id).pick("AVG(rating)", "COUNT(id)")
    
    expert_profile.update_columns(
      average_rating: avg_rating.to_f.round(2),
      reviews_count: rating_count.to_i
    )
  end
end
