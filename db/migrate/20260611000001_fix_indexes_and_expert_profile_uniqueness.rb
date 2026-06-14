class FixIndexesAndExpertProfileUniqueness < ActiveRecord::Migration[8.1]
  def change
    # expert_profiles: the original unique index is on user_id alone, which prevents one user
    # from being an expert on multiple marketplaces. Change to a composite unique on (user_id, tenant_id).
    remove_index :expert_profiles, :user_id if index_exists?(:expert_profiles, :user_id, unique: true)
    add_index :expert_profiles, [:user_id, :tenant_id], unique: true, name: "index_expert_profiles_on_user_id_and_tenant_id"

    # messages: efficient pagination within a conversation
    add_index :messages, [:conversation_id, :created_at],
              name: "index_messages_on_conversation_id_and_created_at"

    # notifications: fast unread lookup per user per tenant
    add_index :notifications, [:tenant_id, :user_id, :created_at],
              name: "index_notifications_on_tenant_user_created"

    # enrollments: user's courses within a tenant
    add_index :enrollments, [:tenant_id, :user_id],
              name: "index_enrollments_on_tenant_id_and_user_id"

    # subscriptions: look up by Stripe subscription id
    add_index :subscriptions, :stripe_subscription_id,
              name: "index_subscriptions_on_stripe_subscription_id",
              where: "stripe_subscription_id IS NOT NULL"

    # group_sessions: upcoming sessions sorted by time
    add_index :group_sessions, [:tenant_id, :start_time],
              name: "index_group_sessions_on_tenant_id_and_start_time"
  end
end
