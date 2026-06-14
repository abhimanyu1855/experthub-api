# frozen_string_literal: true

class CheckoutField < ApplicationRecord
  belongs_to :tenant
  has_many :values, class_name: "CheckoutFieldValue", dependent: :destroy

  validates :field_name, presence: true
  validates :field_type, presence: true, inclusion: { in: %w[text number select] }
end
