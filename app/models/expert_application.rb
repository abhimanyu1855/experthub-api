# frozen_string_literal: true

class ExpertApplication < ApplicationRecord
  belongs_to :user
  belongs_to :tenant

  # Devise status
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, default: "pending"

  validates :status, presence: true
end
