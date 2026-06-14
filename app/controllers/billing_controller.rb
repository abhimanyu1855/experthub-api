# frozen_string_literal: true

class BillingController < ApplicationController
  skip_before_action :require_tenant_membership!, only: [:webhook]
  skip_before_action :authenticate_user!, only: [:webhook]
  skip_before_action :set_current_tenant, only: [:webhook]
  skip_before_action :check_plan_access!, only: [:webhook, :checkout]
  before_action :require_operator!, except: [:webhook]

  # POST /billing/checkout
  # Creates a Stripe Checkout Session for a plan upgrade.
  # The operator is redirected to Stripe's hosted checkout page.
  def checkout
    plan = params[:plan]
    unless PlatformBillingService::PLANS.key?(plan)
      return render json: { error: "Invalid plan" }, status: :unprocessable_entity
    end

    app_domain  = ENV.fetch("APP_DOMAIN", "experthub.app")
    success_url = "https://#{current_tenant.ident}.#{app_domain}/admin/getting-started?upgraded=true"
    cancel_url  = "https://#{current_tenant.ident}.#{app_domain}/admin/getting-started"

    session = PlatformBillingService.create_checkout_session(
      tenant:      current_tenant,
      plan:        plan,
      success_url: success_url,
      cancel_url:  cancel_url
    )

    render json: { checkout_url: session.url }
  end

  # POST /billing/webhook
  # Receives platform Stripe webhook events (signed with PLATFORM_STRIPE_WEBHOOK_SECRET).
  # Skips auth entirely — verified by Stripe signature.
  def webhook
    payload    = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    secret     = ENV.fetch("PLATFORM_STRIPE_WEBHOOK_SECRET", "")

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, secret)
    rescue Stripe::SignatureVerificationError
      return render json: { error: "Invalid signature" }, status: :bad_request
    end

    case event.type
    when "checkout.session.completed"
      PlatformBillingService.handle_checkout_completed(event.data.object)
    when "customer.subscription.deleted"
      PlatformBillingService.handle_subscription_deleted(event.data.object)
    end

    head :ok
  end
end
