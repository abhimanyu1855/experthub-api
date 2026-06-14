# frozen_string_literal: true

class PayoutAccount < ApplicationRecord
  belongs_to :expert_profile

  validates :gateway, presence: true, inclusion: { in: %w[stripe razorpay] }
  validates :account_identifier, presence: true
  validates :status, presence: true

  scope :stripe, -> { where(gateway: "stripe") }
  scope :razorpay, -> { where(gateway: "razorpay") }
  scope :active, -> { where(status: "active") }
end
