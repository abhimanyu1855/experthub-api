# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :require_tenant_membership!
  skip_before_action :check_plan_access!

  # POST /webhooks/stripe
  def stripe
    payload = request.body.read
    sig_header = request.headers["HTTP_STRIPE_SIGNATURE"]

    result = WebhookService.process_stripe_webhook(
      payload: payload,
      sig_header: sig_header,
      tenant: current_tenant
    )

    if result[:status] == :success || result[:status] == :ignored
      render json: { received: true }, status: :ok
    else
      render json: { error: result[:reason] }, status: :bad_request
    end
  rescue WebhookService::WebhookError => e
    render json: { error: e.message }, status: :bad_request
  end

  # POST /webhooks/razorpay
  def razorpay
    payload = request.body.read
    signature = request.headers["HTTP_X_RAZORPAY_SIGNATURE"]

    result = WebhookService.process_razorpay_webhook(
      payload: payload,
      signature: signature,
      tenant: current_tenant
    )

    if result[:status] == :success || result[:status] == :ignored
      render json: { received: true }, status: :ok
    else
      render json: { error: result[:reason] }, status: :bad_request
    end
  rescue WebhookService::WebhookError, RazorpayService::RazorpayError => e
    render json: { error: e.message }, status: :bad_request
  end

  # POST /webhooks/paypal
  def paypal
    payload = request.body.read
    result = WebhookService.process_paypal_webhook(
      payload: payload,
      tenant: current_tenant
    )

    if result[:status] == :success || result[:status] == :ignored
      render json: { received: true }, status: :ok
    elsif result[:status] == :not_implemented
      render json: { error: result[:reason] }, status: :not_implemented
    else
      render json: { error: result[:reason] }, status: :bad_request
    end
  rescue PaypalService::PaypalError => e
    render json: { error: e.message }, status: :bad_request
  end

  # POST /webhooks/payfast
  def payfast
    # Payfast parameters are submitted as form parameters
    result = WebhookService.process_payfast_webhook(
      params: params.to_unsafe_h,
      tenant: current_tenant
    )

    if result[:status] == :success || result[:status] == :ignored
      render json: { received: true }, status: :ok
    elsif result[:status] == :not_implemented
      render json: { error: result[:reason] }, status: :not_implemented
    else
      render json: { error: result[:reason] }, status: :bad_request
    end
  rescue PayfastService::PayfastError => e
    render json: { error: e.message }, status: :bad_request
  end
end

