# Ported from mytin: community_memberships table
# Replaces: community_memberships.status + Person boolean flags (is_admin, is_expert,
#   is_manager, is_hippo_agent, is_buddy_expert) with a single role enum
class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user,   null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.integer :role,   null: false, default: 0  # enum: client=0, expert=1, operator=2, manager=3
      t.integer :status, null: false, default: 0  # enum: pending=0, active=1, banned=2, deleted=3

      t.timestamps
    end

    add_index :memberships, [:user_id, :tenant_id], unique: true
    add_index :memberships, [:tenant_id, :role]
  end
end
