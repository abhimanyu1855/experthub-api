# frozen_string_literal: true

class SessionSummary < ApplicationRecord
  belongs_to :booking

  validates :summary, presence: true
  validates :action_items, presence: true
end
