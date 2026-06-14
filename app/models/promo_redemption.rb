# frozen_string_literal: true

class PromoRedemption < ApplicationRecord
  belongs_to :promo_code
  belongs_to :booking, optional: true
  belongs_to :user

  validates :user_id, presence: true

  after_create_commit :increment_promo_code_redemptions

  private

  def increment_promo_code_redemptions
    promo_code.increment_redemptions!
  end
end
