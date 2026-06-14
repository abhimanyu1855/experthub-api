# frozen_string_literal: true

# Tenant model — maps from mytin's Community (3,308 LOC → ~100 LOC)
# Consolidates: communities, community_customizations, community_themes,
#   commission_settings, marketplace_configurations, feature_flags
class Tenant < ApplicationRecord
  include PlanFeatures

  # --- Associations ---
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :categories, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :expert_profiles, dependent: :destroy
  has_many :payment_configs, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :reschedule_requests, dependent: :destroy
  has_many :cancellation_policies, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :ai_triage_sessions, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :group_sessions, dependent: :destroy
  has_many :booking_packages, dependent: :destroy
  has_many :package_purchases, dependent: :destroy
  has_many :subscription_plans, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :promo_codes, dependent: :destroy
  has_many :checkout_fields, dependent: :destroy
  has_many :pages, dependent: :destroy
  has_many :referral_credits, dependent: :destroy
  has_many :expert_applications, dependent: :destroy
  has_many :tenant_setup_steps, dependent: :destroy


  # --- Validations ---
  validates :ident, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/i, message: "must be alphanumeric with optional hyphens" },
            length: { minimum: 3, maximum: 63 }
  validates :name, presence: true
  validates :domain, uniqueness: true, allow_nil: true
  validates :default_currency, presence: true
  validates :seller_commission_pct, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :buyer_commission_pct, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  RESERVED_SUBDOMAINS = %w[
    www api admin app mail ftp ns1 ns2 ns3 smtp pop imap
    staging dev test demo blog docs help support status
    billing dashboard operator expert client assets cdn
    static media images files uploads download
  ].freeze

  validate :ident_not_reserved

  # --- Scopes ---
  scope :active, -> { where("trial_ends_at IS NULL OR trial_ends_at > ?", Time.current) }
  scope :on_plan, ->(plan) { where(plan: plan) }

  # --- Settings helpers ---
  def setting(key, default = nil)
    settings.fetch(key.to_s, default)
  end

  def feature_enabled?(flag)
    feature_flags.fetch(flag.to_s, false)
  end

  def booking_buffer_minutes
    setting("booking_buffer_minutes", 0).to_i
  end

  def auto_confirm_bookings?
    setting("auto_confirm_bookings", false)
  end

  def require_expert_approval?
    setting("require_expert_approval", true)
  end

  def trial_active?
    trial_ends_at.nil? || trial_ends_at > Time.current
  end

  # --- Commission cascade (from mytin transaction.rb L605-640) ---
  # Returns the applicable commission rate for an expert in a category
  # Priority: expert override > category override > tenant default
  def commission_rate_for(expert_profile: nil, category: nil)
    # Phase 2: Check expert-specific override
    # Phase 2: Check category-specific override
    # Phase 1: Return tenant default
    seller_commission_pct
  end

  private

  def ident_not_reserved
    errors.add(:ident, "is reserved") if RESERVED_SUBDOMAINS.include?(ident&.downcase)
  end
end
