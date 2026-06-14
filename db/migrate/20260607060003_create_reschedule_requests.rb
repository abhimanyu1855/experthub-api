class CreateRescheduleRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :reschedule_requests do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :booking, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.datetime :old_start_time, null: false
      t.datetime :old_end_time, null: false
      t.datetime :new_start_time, null: false
      t.datetime :new_end_time, null: false
      t.string :status, null: false, default: "pending"
      t.text :reason
      t.datetime :expires_at

      t.timestamps
    end

    add_index :reschedule_requests, [:booking_id, :status]
  end
end
