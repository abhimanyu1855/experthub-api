# frozen_string_literal: true

module PlanFeatures
  PLANS = {
    "free" => {
      max_experts: 2,
      max_services: 5,
      ai_matching: false,
      triage_chatbot: false,
      session_summaries: false,
      custom_domain: false,
      webhooks: false,
      promo_codes: false,
      booking_packages: false,
      subscriptions: false,
      group_sessions: false,
      courses: false,
      advanced_analytics: false,
      remove_branding: false
    },
    "trial" => {
      max_experts: 25,
      max_services: nil,
      ai_matching: true,
      triage_chatbot: true,
      session_summaries: true,
      custom_domain: true,
      webhooks: true,
      promo_codes: true,
      booking_packages: true,
      subscriptions: true,
      group_sessions: true,
      courses: true,
      advanced_analytics: true,
      remove_branding: false
    },
    "starter" => {
      max_experts: 5,
      max_services: 20,
      ai_matching: true,
      triage_chatbot: false,
      session_summaries: false,
      custom_domain: true,
      webhooks: false,
      promo_codes: true,
      booking_packages: false,
      subscriptions: false,
      group_sessions: true,
      courses: false,
      advanced_analytics: false,
      remove_branding: false
    },
    "pro" => {
      max_experts: 25,
      max_services: nil,
      ai_matching: true,
      triage_chatbot: true,
      session_summaries: true,
      custom_domain: true,
      webhooks: true,
      promo_codes: true,
      booking_packages: true,
      subscriptions: true,
      group_sessions: true,
      courses: true,
      advanced_analytics: true,
      remove_branding: false
    },
    "scale" => {
      max_experts: nil,
      max_services: nil,
      ai_matching: true,
      triage_chatbot: true,
      session_summaries: true,
      custom_domain: true,
      webhooks: true,
      promo_codes: true,
      booking_packages: true,
      subscriptions: true,
      group_sessions: true,
      courses: true,
      advanced_analytics: true,
      remove_branding: true
    }
  }.freeze

  def plan_features
    PLANS[plan] || PLANS["free"]
  end

  def feature_allowed?(feature)
    plan_features[feature.to_sym]
  end

  def within_expert_limit?
    max = plan_features[:max_experts]
    return true if max.nil?
    memberships.where(role: :expert).count < max
  end
end
