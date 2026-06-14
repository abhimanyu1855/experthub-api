# frozen_string_literal: true

class ExpertEmbedding < ApplicationRecord
  has_neighbors :embedding

  belongs_to :expert_profile

  validates :embedding, presence: true
  validates :content_hash, presence: true
end
