# frozen_string_literal: true

class Service < ApplicationRecord
  belongs_to :expert_profile
  belongs_to :tenant
  belongs_to :category, optional: true

  has_many :bookings, dependent: :destroy
  has_many :blocked_dates, dependent: :destroy
  belongs_to :cancellation_policy, optional: true

  enum :approval_status, { pending_review: 0, approved: 1, rejected: 2 }

  validates :title, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :duration_minutes, numericality: { greater_than: 0 }

  scope :active_approved, -> { where(approval_status: :approved, is_active: true) }
  scope :by_category, ->(cat_id) { where(category_id: cat_id) if cat_id }

  def price_display
    Money.new(price_cents, currency).format
  end

  def free?
    price_cents.zero?
  end
end
