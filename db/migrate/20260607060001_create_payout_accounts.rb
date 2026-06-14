class CreatePayoutAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :payout_accounts do |t|
      t.references :expert_profile, null: false, foreign_key: true
      t.string :gateway, null: false
      t.string :account_identifier, null: false
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :payout_accounts, [:expert_profile_id, :gateway], unique: true
  end
end
