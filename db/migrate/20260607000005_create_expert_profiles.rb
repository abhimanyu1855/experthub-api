# Expert-specific data split from mytin's Person model
# Maps: people (expert columns) → expert_profiles
# Key columns: work_offset, slot_interval, specialization, is_on_duty
class CreateExpertProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :expert_profiles do |t|
      t.references :user,   null: false, foreign_key: true, index: { unique: true }
      t.references :tenant, null: false, foreign_key: true

      # Professional info
      t.text   :specialization
      t.text   :bio
      t.string :title   # "Dr.", "Attorney", etc.

      # Availability (from person.work_offset, person.slot_interval)
      t.integer :timezone_offset, default: 0  # minutes from UTC (mytin uses -330 for IST)
      t.integer :default_slot_duration, default: 30  # minutes
      t.boolean :is_on_duty, default: true

      # Approval (replaces is_approved integer on listings)
      t.integer :approval_status, default: 0  # enum: pending=0, approved=1, rejected=2
      t.string  :rejection_message

      # Stats (cached)
      t.decimal :average_rating, precision: 3, scale: 2, default: 0.0
      t.integer :reviews_count, default: 0
      t.integer :bookings_count, default: 0

      # Payout
      t.string :stripe_account_id  # Stripe Connect account

      t.timestamps
    end

    add_index :expert_profiles, [:tenant_id, :approval_status]
  end
end
