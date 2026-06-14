class CreateGroupSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :group_sessions do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :expert_profile, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.integer :price_cents, null: false, default: 0
      t.string :currency, null: false, default: "USD"
      t.integer :max_participants, null: false, default: 10
      t.string :video_room_url

      t.timestamps
    end

    create_table :session_attendances do |t|
      t.references :group_session, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "registered"

      t.timestamps
    end

    add_index :session_attendances, [:group_session_id, :user_id], unique: true
  end
end
