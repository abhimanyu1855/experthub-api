# frozen_string_literal: true

class VideoRoom < ApplicationRecord
  belongs_to :booking, optional: true
  validates :url, :provider, presence: true
end
