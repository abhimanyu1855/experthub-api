# frozen_string_literal: true

class ExpertsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  skip_before_action :require_tenant_membership!, only: [:index, :show]
  before_action :require_expert!, only: [:update_profile, :stripe_account, :stripe_onboarding_link]

  # GET /experts
  def index
    experts = current_tenant.expert_profiles.approved.includes(:user)

    if params[:specialization].present?
      experts = experts.where("specialization ILIKE ?", "%#{params[:specialization]}%")
    end

    if params[:q].present?
      experts = experts.joins(:user).where(
        "users.given_name ILIKE :q OR users.family_name ILIKE :q OR expert_profiles.specialization ILIKE :q OR expert_profiles.bio ILIKE :q",
        q: "%#{params[:q]}%"
      )
    end

    users = experts.map(&:user).compact
    render json: UserBlueprint.render_as_hash(users)
  end

  # GET /experts/:id
  def show
    expert = current_tenant.expert_profiles.approved.find(params[:id])
    render json: UserBlueprint.render_as_hash(expert.user)
  end

  # PATCH /experts/profile
  def update_profile
    profile = current_user.expert_profile
    return render json: { error: "Expert profile not found" }, status: :not_found unless profile

    if profile.update(expert_profile_params)
      render json: ExpertProfileBlueprint.render_as_hash(profile)
    else
      render json: { errors: profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /experts/stripe_account
  def stripe_account
    profile = current_expert_profile
    return if performed?

    account_id = StripeService.create_express_account(
      expert_profile: profile,
      tenant: current_tenant,
      email: current_user.email
    )

    render json: { account_id: account_id }, status: :ok
  rescue StripeService::StripeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /experts/stripe_onboarding_link
  def stripe_onboarding_link
    profile = current_expert_profile
    return if performed?

    link = StripeService.create_account_link(
      expert_profile: profile,
      tenant: current_tenant,
      refresh_url: params[:refresh_url].presence || default_stripe_onboarding_url,
      return_url: params[:return_url].presence || default_stripe_onboarding_url
    )

    render json: { url: link.url }, status: :ok
  rescue StripeService::StripeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def current_expert_profile
    profile = current_tenant.expert_profiles.find_by(user: current_user)
    return profile if profile

    render json: { error: "Expert profile not found" }, status: :not_found
    nil
  end

  def default_stripe_onboarding_url
    app_domain = ENV.fetch("APP_DOMAIN", "experthub.app")
    "https://#{current_tenant.ident}.#{app_domain}/expert/payouts"
  end

  def expert_profile_params
    params.permit(:bio, :specialization, :title, :default_slot_duration, :timezone_offset, :is_on_duty, :intro_video_url, press_links: [:name, :url], credentials: [:name, :details])
  end
end
