# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :tenant
  belongs_to :user
  belongs_to :subscription_plan

  validates :status, presence: true, inclusion: { in: %w[active trialing canceled past_due] }
  
  scope :active, -> { where(status: %w[active trialing]) }

  def active?
    %w[active trialing].include?(status)
  end

  def cancel!
    update!(status: "canceled")
  end
end
