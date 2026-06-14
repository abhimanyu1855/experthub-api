# frozen_string_literal: true

class PaymentRecord < ApplicationRecord
  belongs_to :booking
  validates :gateway, :amount_cents, :currency, presence: true
end
