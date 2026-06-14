# frozen_string_literal: true

class TenantSetupStep < ApplicationRecord
  belongs_to :tenant

  validates :step_id, presence: true, uniqueness: { scope: :tenant_id }
end
