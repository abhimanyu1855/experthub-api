# frozen_string_literal: true

class SubscriptionPlansController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  skip_before_action :require_tenant_membership!, only: [:index]
  before_action :require_operator!, only: [:create, :update]

  # GET /subscription_plans
  def index
    plans = current_tenant.subscription_plans
    render json: plans.as_json(methods: [:active_subscribers_count])
  end

  # POST /subscription_plans
  def create
    plan = current_tenant.subscription_plans.new(plan_params)

    if plan.save
      render json: plan, status: :created
    else
      render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /subscription_plans/:id
  def update
    plan = current_tenant.subscription_plans.find(params[:id])
    if plan.update(plan_params)
      render json: plan
    else
      render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def plan_params
    params.require(:subscription_plan).permit(:name, :description, :price_cents, :currency, :billing_interval, :target_role, :is_active, features: [])
  end
end
