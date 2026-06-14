# frozen_string_literal: true

class BookingBlueprint < Blueprinter::Base
  identifier :id

  fields :aasm_state, :start_time, :end_time, :duration_minutes, :price_cents, :commission_cents, :buyer_fee_cents, :expert_payout_cents, :currency, :discount_cents, :promo_code, :stripe_payment_intent_id, :stripe_transfer_id, :payment_status, :video_room_url, :video_room_provider, :video_room_id, :auto_confirm_at, :metadata, :created_at

  field :session_summary do |booking|
    next nil unless booking.session_summary

    {
      summary: booking.session_summary.summary,
      action_items: booking.session_summary.action_items,
      updated_at: booking.session_summary.updated_at
    }
  end

  association :service, blueprint: ServiceBlueprint
  association :client, blueprint: UserBlueprint
  association :expert, blueprint: UserBlueprint
end
