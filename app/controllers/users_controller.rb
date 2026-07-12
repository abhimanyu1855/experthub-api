# frozen_string_literal: true

class UsersController < ApplicationController
  def tenant_required?
    false
  end

  def me
    active_membership = current_membership
    if active_membership.nil? && Current.tenant.nil?
      active_membership = current_user.memberships.find_by(role: "operator")
    end

    user_data = UserBlueprint.render_as_hash(current_user)
    user_data[:avatar_url] = current_user.avatar.attached? ? url_for(current_user.avatar) : nil

    render json: {
      user: user_data,
      membership: active_membership ? {
        id: active_membership.id,
        role: active_membership.role,
        status: active_membership.status,
        tenant_id: active_membership.tenant_id,
        tenant_ident: active_membership.tenant.ident
      } : nil
    }
  end

  def update
    if current_user.update(user_params)
      if current_membership&.role == "expert"
        profile = current_user.expert_profile
        if profile
          profile.update(expert_profile_params)
        end
      end

      user_data = UserBlueprint.render_as_hash(current_user)
      user_data[:avatar_url] = current_user.avatar.attached? ? url_for(current_user.avatar) : nil

      render json: {
        status: { code: 200, message: "Profile updated successfully." },
        user: user_data,
        avatar_url: user_data[:avatar_url]
      }
    else
      render json: { error: current_user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:given_name, :family_name, :display_name, :phone_number, :avatar)
  end

  def expert_profile_params
    params.permit(:specialization, :bio, :title)
  end
end
