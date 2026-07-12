# frozen_string_literal: true

# TenantSetupService — creates a new tenant with all defaults
# mytin equivalent: MarketplaceService L116-140 (community creation flow)
class TenantSetupService
  def self.create(params:, admin_user:)
    new(params: params, admin_user: admin_user).call
  end

  def initialize(params:, admin_user:)
    @params = params
    @admin_user = admin_user
  end

  def call
    ActiveRecord::Base.transaction do
      tenant = create_tenant
      create_operator_membership(tenant)
      create_default_category(tenant)
      setup_development_stripe_config(tenant) if Rails.env.development? || Rails.env.test?

      tenant
    end
  end

  private

  def setup_development_stripe_config(tenant)
    publishable_key = ENV["DEV_STRIPE_PUBLISHABLE_KEY"]
    secret_key = ENV["DEV_STRIPE_SECRET_KEY"]
    return if publishable_key.blank? || secret_key.blank?

    PaymentConfig.create!(
      tenant: tenant,
      gateway: "stripe",
      publishable_key: publishable_key,
      encrypted_credentials: { "secret_key" => secret_key }.to_json,
      is_active: true
    )
  end

  def create_tenant
    Tenant.create!(
      ident: @params[:ident],
      name: @params[:name],
      locked_vertical: @params[:locked_vertical],
      default_currency: @params.fetch(:currency, "USD"),
      seller_commission_pct: @params.fetch(:seller_commission_pct, 15.0),
      plan: "trial",
      trial_ends_at: 14.days.from_now,
      settings: default_settings,
      feature_flags: default_feature_flags
    )
  end

  def create_operator_membership(tenant)
    Membership.create!(
      user: @admin_user,
      tenant: tenant,
      role: :operator,
      status: :active
    )
  end

  def create_default_category(tenant)
    Category.create!(
      tenant: tenant,
      name: "General",
      slug: "general",
      category_type: "service"
    )
  end

  def default_settings
    {
      "booking_buffer_minutes" => 30,
      "auto_confirm_bookings" => false,
      "require_expert_approval" => false,
      "send_booking_emails" => true,
      "webhooks_enabled" => false,
      "enable_courses" => false,
      "enable_sessions" => false,
      "enable_packages" => false,
      "enable_subscriptions" => false
    }
  end

  def default_feature_flags
    {
      "ai_matching" => true,
      "triage_chatbot" => true,
      "session_summaries" => true
    }
  end
end
