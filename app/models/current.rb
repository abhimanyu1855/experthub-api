# Thread-local tenant scoping — replaces mytin's @current_community pattern
# Every request sets Current.tenant from subdomain in ApplicationController
class Current < ActiveSupport::CurrentAttributes
  attribute :tenant, :user, :membership

  def tenant!
    tenant or raise "Tenant not set — request must resolve a tenant from subdomain"
  end
end
