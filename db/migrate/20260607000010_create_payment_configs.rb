# Tenant payment gateway credentials (encrypted)
class CreatePaymentConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_configs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string  :gateway, null: false  # stripe, razorpay
      t.boolean :is_active, default: true

      # Encrypted credentials stored via Rails encrypted attributes
      t.text :encrypted_credentials
      t.string :publishable_key  # public key (safe to expose to frontend)

      t.timestamps
    end

    add_index :payment_configs, [:tenant_id, :gateway], unique: true
  end
end
