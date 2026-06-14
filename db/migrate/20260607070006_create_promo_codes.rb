class CreatePromoCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :promo_codes do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :discount_type, null: false # e.g. "percent", "fixed"
      t.decimal :discount_value, precision: 10, scale: 2, null: false
      t.datetime :expires_at
      t.integer :max_redemptions
      t.integer :redemptions_count, null: false, default: 0

      t.timestamps
    end

    add_index :promo_codes, [:tenant_id, :code], unique: true

    create_table :promo_redemptions do |t|
      t.references :promo_code, null: false, foreign_key: true
      t.references :booking, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
