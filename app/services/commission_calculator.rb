# frozen_string_literal: true

# Ported from mytin: transaction.rb L605-640 (commission methods)
# Implements the 3-tier commission cascade:
# 1. Expert profile level override (if configured)
# 2. Category level override (if configured)
# 3. Tenant-level default percentage
# Includes minimum commission floor enforcement and buyer transaction fees.
class CommissionCalculator
  def self.calculate(booking)
    tenant = booking.tenant
    price_cents = booking.price_cents

    commission_model = tenant.setting("commission_model", "percentage")

    if commission_model == "flat"
      commission_cents = tenant.setting("commission_flat_fee_cents", 0).to_i
    else
      # 3-tier cascade rate resolution
      rate = tenant.commission_rate_for(
        expert_profile: booking.service.expert_profile,
        category: booking.service.category
      )
      min_commission = tenant.minimum_commission_cents || 0
      max_commission = tenant.setting("max_commission_cents", nil)

      # Calculate seller commission (enforce minimum commission floor)
      calc_commission = (price_cents * rate / 100.0).round
      commission_cents = [calc_commission, min_commission].max

      # Enforce maximum commission cap if configured
      if max_commission.present?
        commission_cents = [commission_cents, max_commission.to_i].min
      end
    end

    # Calculate buyer fee
    buyer_rate = tenant.buyer_commission_pct || 0.0
    buyer_fee_cents = (price_cents * buyer_rate / 100.0).round

    # Calculate expert payout
    expert_payout_cents = price_cents - commission_cents

    {
      commission_cents: commission_cents,
      buyer_fee_cents: buyer_fee_cents,
      expert_payout_cents: expert_payout_cents
    }
  end
end
