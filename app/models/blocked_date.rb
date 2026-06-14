# frozen_string_literal: true

class BlockedDate < ApplicationRecord
  belongs_to :service
  validates :blocked_on, presence: true, uniqueness: { scope: :service_id }
end
