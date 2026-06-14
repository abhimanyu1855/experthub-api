# frozen_string_literal: true

class PaymentConfigsController < ApplicationController
  before_action :require_operator!

  # GET /payment_configs
  def index
    render json: current_tenant.payment_configs
  end

  # POST /payment_configs
  def create
    gateway = payment_config_params[:gateway]
    unless %w[stripe razorpay].include?(gateway)
      return render json: { error: "Unsupported gateway: #{gateway}" }, status: :bad_request
    end

    config = current_tenant.payment_configs.find_or_initialize_by(gateway: gateway)
    config.assign_attributes(payment_config_params)

    if config.save
      if config.is_active
        # Deactivate other gateways to ensure only one is active
        current_tenant.payment_configs.where.not(id: config.id).update_all(is_active: false)
      end
      render json: config, status: :ok
    else
      render json: { errors: config.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def payment_config_params
    params.require(:payment_config).permit(:gateway, :encrypted_credentials, :publishable_key, :is_active)
  end
end
