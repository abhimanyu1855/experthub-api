# frozen_string_literal: true

class CancellationPoliciesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show]
  skip_before_action :require_tenant_membership!, only: [:show]
  before_action :require_operator!, only: [:create, :update]

  # GET /cancellation_policy
  def show
    policy = current_tenant.cancellation_policies.active.first
    if policy
      render json: policy
    else
      render json: { policy: nil }, status: :ok
    end
  end

  # POST /cancellation_policy
  def create
    policy = current_tenant.cancellation_policies.new(policy_params)
    if policy.save
      render json: policy, status: :created
    else
      render json: { errors: policy.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /cancellation_policy
  def update
    policy = current_tenant.cancellation_policies.first_or_initialize
    if policy.update(policy_params)
      render json: policy
    else
      render json: { errors: policy.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def policy_params
    params.require(:cancellation_policy).permit(:name, :refund_percentage, :prior_hours, :is_active)
  end
end
