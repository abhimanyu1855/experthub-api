# frozen_string_literal: true

class ReferralService
  # Check if client was referred, and if this is their first paid booking, reward both referrer and referee
  def self.check_and_reward!(booking)
    tenant = booking.tenant
    client = booking.client

    return unless client.referred_by_code.present?

    # Verify if referral reward has already been issued for this referred user on this tenant
    return if ReferralCredit.exists?(referred_user_id: client.id, tenant_id: tenant.id)

    # Find the referrer
    referrer = User.find_by(referral_code: client.referred_by_code)
    return unless referrer

    reward_cents = tenant.setting("referral_reward_cents", 1000).to_i

    ActiveRecord::Base.transaction do
      # Referrer credit
      ReferralCredit.create!(
        tenant: tenant,
        user: referrer,
        amount_cents: reward_cents,
        currency: booking.currency,
        status: "active",
        referred_user_id: client.id
      )

      # Referee credit
      ReferralCredit.create!(
        tenant: tenant,
        user: client,
        amount_cents: reward_cents,
        currency: booking.currency,
        status: "active",
        referred_user_id: client.id
      )
    end
  end

  # Calculate and apply available referral credits as discount to a booking
  def self.apply_credits!(booking)
    tenant = booking.tenant
    client = booking.client

    active_credits = client.referral_credits.active.where(tenant: tenant)
    available_credits_cents = active_credits.sum(:amount_cents)

    return if available_credits_cents.zero?

    # Apply credits up to the booking's price
    referral_discount = [available_credits_cents, booking.price_cents].min
    booking.discount_cents = (booking.discount_cents || 0) + referral_discount
  end

  # Mark referral credits as redeemed up to the booking's discount amount
  def self.redeem_credits!(booking)
    return unless booking.discount_cents.present? && booking.discount_cents > 0

    remaining_to_redeem = booking.discount_cents
    tenant = booking.tenant
    client = booking.client

    ActiveRecord::Base.transaction do
      client.referral_credits.active.where(tenant: tenant).order(created_at: :asc).each do |credit|
        break if remaining_to_redeem <= 0

        if credit.amount_cents <= remaining_to_redeem
          remaining_to_redeem -= credit.amount_cents
          credit.update!(status: "redeemed")
        else
          credit.update!(amount_cents: credit.amount_cents - remaining_to_redeem)
          remaining_to_redeem = 0
        end

      end
    end
  end
end
