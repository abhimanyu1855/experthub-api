# Ported from mytin: listings table (1,864 LOC) → services
# Key columns kept: title, description, price_cents, currency, duration,
#   approval state, availability config, security_deposit
# Removed: all Sharetribe listing_shape/listing_type cruft, Sphinx delta,
#   share_type, inventory fields (not needed for consultation marketplace)
class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :expert_profile, null: false, foreign_key: true
      t.references :tenant,         null: false, foreign_key: true
      t.references :category,       foreign_key: true

      # Core
      t.string  :title, null: false
      t.text    :description
      t.string  :slug

      # Pricing (from listings.price_cents + currency)
      t.integer :price_cents, null: false, default: 0
      t.string  :currency, null: false, default: "USD"

      # Scheduling (from listings.default_consultation_duration, schedule_slot_interval)
      t.integer :duration_minutes, default: 30
      t.integer :slot_interval_minutes, default: 30  # can differ from duration
      t.integer :booking_buffer_minutes, default: 0

      # Capacity (from listings.multiple_joinees)
      t.boolean :allow_multiple_bookings, default: false
      t.integer :max_concurrent_bookings, default: 1

      # Approval (from listings.state enum)
      t.integer :approval_status, default: 0  # pending=0, approved=1, rejected=2
      t.string  :rejection_message
      t.boolean :is_active, default: true

      # Video (from listings.room_type)
      t.integer :room_type, default: 3  # 1=hippo(dead), 2=zoom, 3=daily

      # Display
      t.integer :times_viewed, default: 0
      t.integer :sort_position, default: 0
      t.boolean :is_featured, default: false

      t.timestamps
    end

    add_index :services, [:tenant_id, :approval_status, :is_active]
    add_index :services, [:tenant_id, :slug], unique: true
  end
end
