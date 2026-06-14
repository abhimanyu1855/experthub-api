# frozen_string_literal: true

# Platform billing uses the PLATFORM_STRIPE_SECRET_KEY env var.
# This is ExpertHub's own Stripe account — NOT the per-tenant Stripe accounts
# stored in PaymentConfig. Those handle marketplace transactions; this handles
# charging marketplace admins (operators) for their ExpertHub plan.
class PlatformBillingService
  PLANS = {
    "starter" => { price_id: ENV["STRIPE_STARTER_PRICE_ID"], max_experts: 5 },
    "pro"     => { price_id: ENV["STRIPE_PRO_PRICE_ID"],     max_experts: 25 },
    "scale"   => { price_id: ENV["STRIPE_SCALE_PRICE_ID"],   max_experts: nil }
  }.freeze

  def self.create_checkout_session(tenant:, plan:, success_url:, cancel_url:)
    Stripe.api_key = ENV.fetch("PLATFORM_STRIPE_SECRET_KEY")

    Stripe::Checkout::Session.create({
      mode: "subscription",
      line_items: [{ price: PLANS[plan][:price_id], quantity: 1 }],
      metadata: { tenant_id: tenant.id, plan: plan },
      success_url: success_url,
      cancel_url: cancel_url,
      client_reference_id: tenant.id.to_s
    })
  end

  def self.handle_checkout_completed(session)
    tenant = Tenant.find(session.metadata["tenant_id"])
    plan   = session.metadata["plan"]

    tenant.update!(
      plan: plan,
      stripe_subscription_id: session.subscription,
      max_experts: PLANS.dig(plan, :max_experts),
      trial_ends_at: nil
    )
  end

  def self.handle_subscription_deleted(subscription)
    tenant = Tenant.find_by(stripe_subscription_id: subscription.id)
    return unless tenant

    tenant.update!(plan: "free", max_experts: 2)
  end
end
