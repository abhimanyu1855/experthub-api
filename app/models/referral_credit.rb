# frozen_string_literal: true

class ReferralCredit < ApplicationRecord
  belongs_to :tenant
  belongs_to :user
  belongs_to :referred_user, class_name: "User", optional: true

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[active redeemed expired] }
  validates :currency, presence: true

  scope :active, -> { where(status: "active") }

  def redeem!
    update!(status: "redeemed")
  end
end
