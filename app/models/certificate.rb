# frozen_string_literal: true

class Certificate < ApplicationRecord
  belongs_to :enrollment

  validates :certificate_code, presence: true, uniqueness: true
  validates :issued_at, presence: true
end
