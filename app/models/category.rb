# frozen_string_literal: true

class Category < ApplicationRecord
  include Localizable

  belongs_to :tenant
  belongs_to :parent, class_name: "Category", optional: true

  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :destroy
  has_many :services

  validates :name, presence: true
  validates :slug, uniqueness: { scope: :tenant_id }, allow_nil: true

  localizable_attributes :name

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }


  scope :roots, -> { where(parent_id: nil) }
  scope :for_type, ->(type) { where(category_type: type) }

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
