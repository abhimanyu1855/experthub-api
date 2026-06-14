# frozen_string_literal: true

class TenantsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:create, :show]
  skip_before_action :set_current_tenant, only: [:create]
  skip_before_action :require_tenant_membership!, only: [:create, :show]
  skip_before_action :check_plan_access!, only: [:create, :show]

  # POST /tenants
  def create
    ActiveRecord::Base.transaction do
      admin = User.find_by(email: admin_params[:email])
      unless admin
        admin = User.new(admin_params)
        admin.skip_confirmation! if Rails.env.development? || Rails.env.test?
        admin.save!
      end

      tenant = TenantSetupService.create(
        params: tenant_params,
        admin_user: admin
      )

      render json: {
        message: "Tenant setup successfully.",
        tenant: tenant,
        admin: UserBlueprint.render_as_hash(admin)
      }, status: :created
    end
  end

  # GET /tenant
  def show
    tenant = current_tenant
    render json: tenant.as_json.merge(
      active_payment_gateway: tenant.payment_configs.active.order(:created_at).first&.gateway,
      plan_features: tenant.plan_features,
      trial_days_remaining: tenant.trial_ends_at ? [(tenant.trial_ends_at.to_date - Date.current).to_i, 0].max : nil
    )
  end

  # PUT/PATCH /tenant
  def update
    require_operator!
    return if performed?

    if current_tenant.update(tenant_update_params)
      render json: current_tenant
    else
      render json: { errors: current_tenant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def tenant_params
    params.require(:tenant).permit(:ident, :name, :default_currency, :seller_commission_pct, :buyer_commission_pct, :locked_vertical)
  end

  def admin_params
    params.require(:admin).permit(:email, :password, :given_name, :family_name)
  end

  def tenant_update_params
    params.require(:tenant).permit(:name, :logo_url, :cover_photo_url, :slogan, :description, :seller_commission_pct, :buyer_commission_pct, :minimum_commission_cents, :custom_domain, settings: {}, feature_flags: {}, theme: {})
  end
end
