# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  before_action -> { require_feature!(:subscriptions) }, only: [:create]

  # GET /subscriptions
  def index
    subscriptions = current_user.subscriptions.where(tenant: current_tenant)
    render json: subscriptions
  end

  # POST /subscriptions
  def create
    plan = current_tenant.subscription_plans.find(params[:subscription_plan_id])
    
    subscription = current_tenant.subscriptions.new(
      user: current_user,
      subscription_plan: plan,
      status: "active",
      current_period_end: Time.current + 1.month
    )

    if subscription.save
      render json: subscription, status: :created
    else
      render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /subscriptions/:id/cancel
  def cancel
    subscription = current_user.subscriptions.where(tenant: current_tenant).find(params[:id])
    subscription.cancel!
    render json: subscription
  end
end
