# frozen_string_literal: true

class AddStripeSubscriptionToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :stripe_subscription_id, :string
    add_index  :tenants, :stripe_subscription_id, unique: true,
               where: "(stripe_subscription_id IS NOT NULL)",
               name: "index_tenants_on_stripe_subscription_id"
  end
end
