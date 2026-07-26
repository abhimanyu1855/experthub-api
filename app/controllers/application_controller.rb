# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Pundit::Authorization
  before_action :authenticate_user!
  before_action :set_current_tenant
  before_action :set_locale
  before_action :set_active_storage_url_options
  before_action :require_tenant_membership!, unless: :devise_controller?
  before_action :check_plan_access!

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from BookingService::BookingError, with: :unprocessable_entity

  private

  def set_locale
    locale = params[:locale] || extract_locale_from_header
    I18n.locale = if locale && Current.tenant&.supported_locales&.include?(locale.to_s)
                    locale
                  else
                    Current.tenant&.locale || I18n.default_locale
                  end
  end

  def extract_locale_from_header
    header = request.headers["Accept-Language"]
    return nil unless header

    header.scan(/^[a-z]{2}/).first
  end


  private

  def set_active_storage_url_options
    ActiveStorage::Current.url_options = { host: request.base_url }
  end

  # Resolve tenant from X-Tenant-Id header or subdomain
  # mytin equivalent: ApplicationController#current_community (from subdomain)
  def set_current_tenant
    tenant = resolve_tenant
    return render json: { error: "Tenant not found" }, status: :not_found if tenant.nil? && tenant_required?

    Current.tenant = tenant
  end

  def resolve_tenant
    # 1. Explicit header (used by FE for all API calls)
    ident = request.headers["X-Tenant-Id"]
    return Tenant.find_by(ident: ident) if ident.present?

    host = request.host
    app_domain = ENV.fetch("APP_DOMAIN", "experthub.localhost")

    # 2. Subdomain of the app domain
    subdomain = host.sub(/\.#{Regexp.escape(app_domain)}$/, "").presence
    if subdomain && subdomain != app_domain && !%w[localhost 127.0.0.1 www].include?(subdomain)
      return Tenant.find_by(ident: subdomain)
    end

    # 3. Full custom domain (e.g. mysite.com)
    Tenant.find_by(custom_domain: host)
  end

  def tenant_required?
    return false if devise_controller?
    return false if controller_name == "users" && action_name == "me"
    true
  end

  def extract_subdomain
    host = request.host
    app_domain = ENV.fetch("APP_DOMAIN", "experthub.localhost")
    return nil if host == app_domain
    return nil if %w[localhost 127.0.0.1].include?(host)

    host.sub(/\.#{Regexp.escape(app_domain)}$/, "").presence
  end

  def current_tenant
    Current.tenant!
  end

  def current_membership
    return nil unless Current.tenant
    Current.membership ||= current_user.memberships.find_by(tenant: current_tenant)
  end

  def require_operator!
    unless current_membership&.operator?
      render json: { error: "Operator access required" }, status: :forbidden
    end
  end

  def require_expert!
    unless current_membership&.expert? || current_membership&.operator?
      render json: { error: "Expert access required" }, status: :forbidden
    end
  end

  def require_tenant_membership!
    return unless current_user
    return unless Current.tenant

    if current_membership.nil?
      render json: { error: "Not a member of this tenant" }, status: :forbidden
    end
  end

  # Block non-GET writes when a free-plan tenant's trial has expired.
  # Skipped automatically for: Devise, billing, tenant create, and webhook routes.
  def check_plan_access!
    return if devise_controller?
    return if request.get?
    return unless Current.tenant

    tenant = Current.tenant
    return unless tenant.plan == "free" || tenant.plan == "trial"
    return unless tenant.trial_ends_at.present? && tenant.trial_ends_at < Time.current

    app_domain  = ENV.fetch("APP_DOMAIN", "experthub.app")
    upgrade_url = "https://#{tenant.ident}.#{app_domain}/admin/getting-started"

    render json: { error: "Trial expired", upgrade_url: upgrade_url }, status: :payment_required
  end

  def not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end

  def require_feature!(feature)
    unless current_tenant.feature_allowed?(feature)
      render json: {
        error: "This feature requires a higher plan",
        feature: feature,
        current_plan: current_tenant.plan,
        upgrade_required: true
      }, status: :payment_required
    end
  end

  def forbidden(_exception)
    render json: { error: "Not authorized" }, status: :forbidden
  end
end
