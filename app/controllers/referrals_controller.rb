# frozen_string_literal: true

class ReferralsController < ApplicationController
  # GET /referrals/summary
  def summary
    referred_users_count = User.where(referred_by_code: current_user.referral_code).count
    active_credits_cents = current_user.referral_credits.active.where(tenant: current_tenant).sum(:amount_cents)

    render json: {
      referral_code: current_user.referral_code,
      referred_users_count: referred_users_count,
      active_credits_cents: active_credits_cents,
      active_credits_value: active_credits_cents / 100.0
    }
  end
end
