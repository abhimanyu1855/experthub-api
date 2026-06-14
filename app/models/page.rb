# frozen_string_literal: true

class Page < ApplicationRecord
  include Localizable

  belongs_to :tenant

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: { scope: :tenant_id }
  validates :content, presence: true

  localizable_attributes :title, :content

  scope :published, -> { where(is_published: true) }
end

