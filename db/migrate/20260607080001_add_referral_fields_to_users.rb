# frozen_string_literal: true

class AddReferralFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :referral_code
      t.string :referred_by_code
    end
    add_index :users, :referral_code, unique: true
  end
end
