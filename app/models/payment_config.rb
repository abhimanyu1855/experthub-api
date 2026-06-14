# frozen_string_literal: true

class PaymentConfig < ApplicationRecord
  belongs_to :tenant

  encrypts :encrypted_credentials

  validates :gateway, presence: true, uniqueness: { scope: :tenant_id }

  scope :active, -> { where(is_active: true) }
  scope :stripe, -> { where(gateway: "stripe") }
  scope :razorpay, -> { where(gateway: "razorpay") }
end
