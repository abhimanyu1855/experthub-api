# Ported from mytin: person.working_time_slots + listing_working_hours
class CreateWorkingTimeSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :working_time_slots do |t|
      t.references :expert_profile, null: false, foreign_key: true
      t.integer :week_day, null: false  # 1=Mon .. 7=Sun (ISO)
      t.string  :from_time, null: false # "09:00"
      t.string  :till_time, null: false # "17:00"
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :working_time_slots, [:expert_profile_id, :week_day]

    create_table :blocked_dates do |t|
      t.references :service, null: false, foreign_key: true
      t.date :blocked_on, null: false

      t.timestamps
    end

    add_index :blocked_dates, [:service_id, :blocked_on], unique: true
  end
end
