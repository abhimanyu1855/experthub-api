# frozen_string_literal: true

class PromoCode < ApplicationRecord
  belongs_to :tenant
  has_many :redemptions, class_name: "PromoRedemption", dependent: :destroy

  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :discount_type, presence: true, inclusion: { in: %w[percent fixed] }
  validates :discount_value, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def max_redemptions_reached?
    max_redemptions.present? && redemptions_count >= max_redemptions
  end

  def valid_for_use?
    !expired? && !max_redemptions_reached?
  end

  def calculate_discount(price_cents)
    return 0 unless valid_for_use?

    if discount_type == "percent"
      # discount_value is e.g. 15.0 for 15%
      discount = (price_cents * (discount_value / 100.0)).round
      [discount, price_cents].min
    else # fixed discount in currency units (e.g. 5.0 means $5.00 = 500 cents)
      discount_cents = (discount_value * 100).to_i
      [discount_cents, price_cents].min
    end
  end

  def increment_redemptions!
    increment!(:redemptions_count)
  end
end
