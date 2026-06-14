# frozen_string_literal: true

class Course < ApplicationRecord
  belongs_to :tenant
  belongs_to :expert_profile
  has_many :lessons, -> { order(sort_priority: :asc) }, dependent: :destroy
  has_many :enrollments, dependent: :destroy

  enum :approval_status, { pending_review: 0, approved: 1, rejected: 2 }

  validates :title, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :active_approved, -> { where(approval_status: :approved, is_active: true) }

  def free?
    price_cents.zero?
  end

  def enrollments_count
    enrollments.count
  end
end
