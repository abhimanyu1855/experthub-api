# Ported from mytin: communities table (3,308 LOC model → ~200 LOC)
# Maps: communities → tenants
# Key columns from mytin: ident, domain, business_type, marketplace_default_type,
#   single_expert_marketplace, enable_courses, enable_sessions, community_billing
class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      # Identity
      t.string :ident, null: false, index: { unique: true } # subdomain identifier
      t.string :name, null: false
      t.string :domain                                        # custom domain (optional)
      t.string :locale, default: "en"

      # Branding (from community_customizations + community_themes)
      t.string :logo_url
      t.string :cover_photo_url
      t.string :slogan
      t.text   :description
      t.jsonb  :theme, default: {}  # { primary_color, secondary_color, font_family }

      # Product configuration (replaces business_type + marketplace_default_type + feature flags)
      t.string  :locked_vertical  # nil = general, "legal", "health", "coaching", etc.
      t.boolean :single_expert, default: false  # single-expert storefront mode

      # Commission (from commission_settings)
      t.decimal :seller_commission_pct, precision: 5, scale: 2, default: 15.0
      t.decimal :buyer_commission_pct,  precision: 5, scale: 2, default: 0.0
      t.integer :minimum_commission_cents, default: 0
      t.string  :default_currency, default: "USD"

      # Billing (replaces community_yelo_plans + marketplace_trials)
      t.string   :plan, default: "trial"  # trial, starter, growth, enterprise
      t.datetime :trial_ends_at
      t.integer  :max_experts  # nil = unlimited

      # Settings (replaces marketplace_configurations — 50+ columns → JSONB)
      t.jsonb :settings, default: {}
      # Expected keys: { booking_buffer_minutes, auto_confirm_bookings,
      #   require_expert_approval, send_booking_emails, webhooks_enabled,
      #   enable_courses, enable_sessions, enable_packages, enable_subscriptions }

      # Feature flags (replaces feature_flags table)
      t.jsonb :feature_flags, default: {}

      t.timestamps
    end

    add_index :tenants, :domain, unique: true, where: "domain IS NOT NULL"
  end
end
