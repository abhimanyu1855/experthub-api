# frozen_string_literal: true

class PackagePurchase < ApplicationRecord
  belongs_to :tenant
  belongs_to :booking_package
  belongs_to :user

  validates :remaining_bookings, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where("remaining_bookings > 0") }

  def use_booking!
    if remaining_bookings <= 0
      raise "No remaining bookings left in this package purchase"
    end
    decrement!(:remaining_bookings)
  end
end
