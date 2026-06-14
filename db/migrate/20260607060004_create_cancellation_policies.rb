class CreateCancellationPolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :cancellation_policies do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :refund_percentage, precision: 5, scale: 2, null: false, default: 100.00
      t.integer :prior_hours, null: false, default: 24
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    add_reference :services, :cancellation_policy, foreign_key: true, null: true
    add_reference :bookings, :cancellation_policy, foreign_key: true, null: true
  end
end
