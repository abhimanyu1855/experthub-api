# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tenant Isolation Integration Tests", type: :request do
  let!(:tenant_a) { create(:tenant, ident: "tenant-a") }
  let!(:tenant_b) { create(:tenant, ident: "tenant-b") }

  let!(:user_a) { create(:user, :confirmed) }
  let!(:membership_a) { create(:membership, user: user_a, tenant: tenant_a, role: :client) }

  let!(:user_b) { create(:user, :confirmed) }
  let!(:membership_b) { create(:membership, user: user_b, tenant: tenant_b, role: :client) }

  let!(:expert_user) { create(:user, :confirmed) }
  let!(:expert_membership) { create(:membership, user: expert_user, tenant: tenant_a, role: :expert) }
  let!(:expert_profile) { create(:expert_profile, user: expert_user, tenant: tenant_a) }
  
  let!(:service_a) { create(:service, expert_profile: expert_profile, tenant: tenant_a) }

  # Log in helper
  def auth_headers(user, tenant)
    post "/login", params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }, headers: { "X-Tenant-Id" => tenant.ident }

    expect(response).to have_http_status(:ok)
    auth_token = response.headers["Authorization"]
    {
      "Authorization" => auth_token,
      "X-Tenant-Id" => tenant.ident,
      "Accept" => "application/json"
    }
  end

  describe "Accessing resources across tenants" do
    context "when authenticated on tenant A" do
      let(:headers_a) { auth_headers(user_a, tenant_a) }

      it "allows viewing a service under tenant A" do
        get "/services/#{service_a.id}", headers: headers_a
        expect(response).to have_http_status(:ok)
      end

      it "returns 404 when trying to access the service of tenant A under tenant B's scope" do
        headers_b_scope = headers_a.merge("X-Tenant-Id" => tenant_b.ident)
        get "/services/#{service_a.id}", headers: headers_b_scope
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when a user has membership on tenant A but requests tenant B endpoints" do
      it "returns 403 Forbidden when trying to view bookings of tenant B" do
        # Log in with tenant B scope but using user A (who has no membership on tenant B)
        # Note: devise login is global, but the membership in the tenant is checked.
        post "/login", params: {
          user: {
            email: user_a.email,
            password: "password123"
          }
        }, headers: { "X-Tenant-Id" => tenant_b.ident }

        expect(response).to have_http_status(:ok)
        auth_token = response.headers["Authorization"]

        headers = {
          "Authorization" => auth_token,
          "X-Tenant-Id" => tenant_b.ident,
          "Accept" => "application/json"
        }

        get "/bookings", headers: headers
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)["error"]).to eq("Not a member of this tenant")
      end
    end
  end
end
