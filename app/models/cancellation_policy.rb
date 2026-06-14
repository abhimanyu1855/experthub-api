# frozen_string_literal: true

class CancellationPolicy < ApplicationRecord
  belongs_to :tenant
  has_many :services, dependent: :nullify
  has_many :bookings, dependent: :nullify

  validates :name, presence: true
  validates :refund_percentage, presence: true, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0 }
  validates :prior_hours, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
end
