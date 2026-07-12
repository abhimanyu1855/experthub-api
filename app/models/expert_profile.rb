# frozen_string_literal: true

class ExpertProfile < ApplicationRecord
  belongs_to :user
  belongs_to :tenant

  has_many :services, dependent: :destroy
  has_many :working_time_slots, dependent: :destroy
  has_many :payout_accounts, dependent: :destroy
  has_one  :expert_embedding, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :group_sessions, dependent: :destroy
  has_many :booking_packages, dependent: :destroy
  has_many :subscription_plans, dependent: :destroy

  enum :approval_status, { pending_approval: 0, approved: 1, rejected: 2 }

  validates :user_id, uniqueness: { scope: :tenant_id }

  scope :approved, -> { where(approval_status: :approved) }
  scope :on_duty, -> { where(is_on_duty: true) }

  after_commit :generate_embedding_async, on: [:create, :update], if: :approved?

  def payout_connected
    stripe_account_id.present? || active_payout_account?
  end

  def payout_onboarding_started
    stripe_account_id.present? || any_payout_account?
  end

  def payout_status
    return "connected" if payout_connected
    return "pending_onboarding" if payout_onboarding_started

    "not_connected"
  end

  private

  def active_payout_account?
    if payout_accounts.loaded?
      payout_accounts.any? { |account| account.status == "active" }
    else
      payout_accounts.active.exists?
    end
  end

  def any_payout_account?
    if payout_accounts.loaded?
      payout_accounts.any?
    else
      payout_accounts.exists?
    end
  end

  def generate_embedding_async
    GenerateEmbeddingJob.perform_later(id)
  end
end
