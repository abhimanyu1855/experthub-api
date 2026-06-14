class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :notification_type, null: false
      t.jsonb :data, default: {}, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:user_id, :read_at]
  end
end
