# frozen_string_literal: true

class BookingPackage < ApplicationRecord
  belongs_to :tenant
  belongs_to :expert_profile
  has_many :purchases, class_name: "PackagePurchase", dependent: :destroy

  validates :title, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :booking_count, numericality: { only_integer: true, greater_than: 0 }
end
