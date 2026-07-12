# frozen_string_literal: true

class SubscriptionPlan < ApplicationRecord
  belongs_to :tenant
  belongs_to :expert_profile, optional: true
  has_many :subscriptions, dependent: :destroy

  validates :name, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :billing_interval, presence: true, inclusion: { in: %w[monthly yearly] }
  validates :target_role, presence: true, inclusion: { in: %w[client expert] }

  def active_subscribers_count
    subscriptions.active.count
  end
end
