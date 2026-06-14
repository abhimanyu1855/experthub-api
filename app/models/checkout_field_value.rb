# frozen_string_literal: true

class CheckoutFieldValue < ApplicationRecord
  belongs_to :checkout_field
  belongs_to :booking

  validates :value, presence: true
  validates :checkout_field_id, uniqueness: { scope: :booking_id }
end
