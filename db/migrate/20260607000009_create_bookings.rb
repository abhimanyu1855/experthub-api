# Ported from mytin: transactions + bookings + scheduled_transactions → bookings
# State machine: 38 states → 15 states (see implementation_plan.md)
# Commission: 3-tier cascade from transaction.commission method (lines 605-640)
class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :service,  null: false, foreign_key: true
      t.references :tenant,   null: false, foreign_key: true
      t.references :client,   null: false, foreign_key: { to_table: :users }
      t.references :expert,   null: false, foreign_key: { to_table: :users }

      # State (AASM — 15 states, ported from TransactionProcessStateMachine)
      t.string :aasm_state, null: false, default: "pending"

      # Schedule (from bookings table in mytin)
      t.datetime :start_time, null: false
      t.datetime :end_time,   null: false
      t.integer  :duration_minutes

      # Pricing (from transactions: payment_total, commission, buyer_commission)
      t.integer :price_cents,      null: false
      t.integer :commission_cents,  null: false, default: 0  # seller commission
      t.integer :buyer_fee_cents,   null: false, default: 0  # buyer fee
      t.integer :expert_payout_cents, null: false, default: 0
      t.string  :currency,         null: false, default: "USD"

      # Promo (from applied_promos)
      t.integer :discount_cents, default: 0
      t.string  :promo_code

      # Payment (Stripe)
      t.string :stripe_payment_intent_id
      t.string :stripe_transfer_id
      t.string :payment_status  # mirrors Stripe status

      # Video room (from scheduled_transactions → video_rooms)
      t.string :video_room_url
      t.string :video_room_provider, default: "daily"
      t.string :video_room_id

      # Calendar (from google_calender_events)
      t.string :calendar_event_id

      # Auto-confirm (from ConfirmConversation)
      t.datetime :auto_confirm_at

      # Metadata
      t.jsonb    :metadata, default: {}  # flexible checkout data
      t.boolean  :deleted, default: false

      t.timestamps
    end

    add_index :bookings, :aasm_state
    add_index :bookings, [:tenant_id, :client_id]
    add_index :bookings, [:tenant_id, :expert_id]
    add_index :bookings, [:expert_id, :start_time, :end_time], name: "idx_bookings_expert_schedule"
    add_index :bookings, :stripe_payment_intent_id, unique: true, where: "stripe_payment_intent_id IS NOT NULL"
    add_index :bookings, [:tenant_id, :aasm_state, :created_at]

    # Audit trail for state transitions (from transaction_transitions)
    create_table :booking_transitions do |t|
      t.references :booking, null: false, foreign_key: true
      t.string  :from_state
      t.string  :to_state, null: false
      t.string  :event
      t.jsonb   :metadata, default: {}
      t.integer :sort_key, null: false

      t.timestamps
    end

    add_index :booking_transitions, [:booking_id, :sort_key], unique: true

    # Payment records (from stripe_payments + razorpay_payments)
    create_table :payment_records do |t|
      t.references :booking, null: false, foreign_key: true
      t.string  :gateway, null: false, default: "stripe"  # stripe, razorpay
      t.string  :provider_id   # Stripe PaymentIntent ID or Razorpay order ID
      t.integer :amount_cents, null: false
      t.string  :currency, null: false
      t.string  :status   # succeeded, failed, pending, refunded
      t.jsonb   :provider_data, default: {}

      t.timestamps
    end

    add_index :payment_records, [:gateway, :provider_id]

    # Video rooms (from daily_expert_appointment_rooms + expert_session_daily_rooms)
    create_table :video_rooms do |t|
      t.references :booking, foreign_key: true
      t.string  :provider, null: false, default: "daily"
      t.string  :url, null: false
      t.string  :provider_room_id
      t.jsonb   :metadata, default: {}

      t.timestamps
    end
  end
end
