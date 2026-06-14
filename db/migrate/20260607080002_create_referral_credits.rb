# frozen_string_literal: true

class CreateReferralCredits < ActiveRecord::Migration[8.1]
  def change
    create_table :referral_credits do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: "USD"
      t.string :status, null: false, default: "active"
      t.references :referred_user, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
