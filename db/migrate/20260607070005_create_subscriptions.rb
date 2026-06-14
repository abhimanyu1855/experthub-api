class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_plans do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :price_cents, null: false
      t.string :currency, null: false, default: "USD"
      t.string :billing_interval, null: false, default: "monthly"
      t.string :target_role, null: false

      t.timestamps
    end

    create_table :subscriptions do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :subscription_plan, null: false, foreign_key: true
      t.string :status, null: false, default: "active"
      t.datetime :current_period_end
      t.string :stripe_subscription_id

      t.timestamps
    end

    add_index :subscriptions, [:user_id, :subscription_plan_id]
  end
end
