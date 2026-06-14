# frozen_string_literal: true

class Admin::UsersController < ApplicationController
  before_action :require_operator!

  # GET /admin/users
  def index
    memberships = current_tenant.memberships
                                .includes(user: [{ expert_profile: :payout_accounts }, :expert_bookings, :client_bookings])

    users_data = memberships.filter_map do |membership|
      user = membership.user
      next unless user

      expert_profile = user.expert_profile
      expert_bookings_count = user.expert_bookings.size
      client_bookings_count = user.client_bookings.size

      {
        id: user.id.to_s,
        name: user.displayed_name,
        email: user.email,
        role: membership.role,
        status: membership.status,
        joined: user.created_at.strftime("%b %d, %Y"),
        bookings_count: expert_bookings_count + client_bookings_count,
        expert_rating: expert_profile&.average_rating,
        payout_connected: expert_profile&.payout_connected,
        payout_onboarding_started: expert_profile&.payout_onboarding_started,
        payout_status: expert_profile&.payout_status,
        spent_earned: membership.role == "expert" \
          ? (expert_profile&.bookings_count.to_i * 100) \
          : (user.client_bookings.sum(&:price_cents) / 100.0)
      }
    end

    render json: users_data
  end

  # PATCH/PUT /admin/users/:id
  def update
    user = current_tenant.users.find(params[:id])
    membership = user.memberships.find_by!(tenant: current_tenant)
    
    if params[:status].present?
      membership.update!(status: params[:status])
    end

    if params[:role].present?
      membership.update!(role: params[:role])
    end

    render json: { message: "User updated successfully", user: user }
  end
end
