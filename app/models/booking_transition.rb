# frozen_string_literal: true

class BookingTransition < ApplicationRecord
  belongs_to :booking
  validates :to_state, :sort_key, presence: true

  before_validation :assign_sort_key, on: :create

  private

  def assign_sort_key
    self.sort_key ||= (booking&.transitions&.maximum(:sort_key) || 0) + 1
  end
end
