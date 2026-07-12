# frozen_string_literal: true

class SubscriptionPlansController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  skip_before_action :require_tenant_membership!, only: [:index]
  before_action :require_expert!, only: [:create, :update]

  # GET /subscription_plans
  def index
    plans = current_tenant.subscription_plans
    if params[:expert_profile_id].present?
      plans = plans.where(expert_profile_id: params[:expert_profile_id])
    else
      plans = plans.where(expert_profile_id: nil)
    end
    render json: plans.as_json(methods: [:active_subscribers_count])
  end

  # POST /subscription_plans
  def create
    if current_membership.operator?
      plan = current_tenant.subscription_plans.new(plan_params)
    elsif current_membership.expert?
      expert_profile = current_user.expert_profile
      return render json: { error: "Expert profile not found" }, status: :not_found unless expert_profile
      
      plan = current_tenant.subscription_plans.new(
        plan_params.merge(
          expert_profile: expert_profile,
          target_role: "client"
        )
      )
    else
      return render json: { error: "Unauthorized" }, status: :forbidden
    end

    if plan.save
      render json: plan, status: :created
    else
      render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /subscription_plans/:id
  def update
    plan = current_tenant.subscription_plans.find(params[:id])
    
    if current_membership.expert? && plan.expert_profile_id != current_user.expert_profile&.id
      return render json: { error: "Not authorized to update this plan" }, status: :forbidden
    end

    if plan.update(plan_params)
      render json: plan
    else
      render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def plan_params
    params.require(:subscription_plan).permit(:name, :price_cents, :currency, :billing_interval, :target_role)
  end
end
