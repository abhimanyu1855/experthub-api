# frozen_string_literal: true

# Membership — replaces mytin's community_memberships + Person boolean flags
# (is_admin, is_expert, is_manager, is_hippo_agent, is_buddy_expert) → single role enum
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :tenant

  enum :role, { client: 0, expert: 1, operator: 2, manager: 3 }
  enum :status, { pending: 0, active: 1, banned: 2, deleted: 3 }, prefix: true

  # --- Validations ---
  validates :user_id, uniqueness: { scope: :tenant_id, message: "already has a membership in this tenant" }
  validates :role, presence: true

  # --- Scopes ---
  scope :active_members, -> { where(status: :active) }
  scope :experts, -> { where(role: :expert, status: :active) }
  scope :operators, -> { where(role: :operator, status: :active) }
end
