# frozen_string_literal: true

module Ai
  class MatchController < ApplicationController
    skip_before_action :authenticate_user!, only: [:match]
    skip_before_action :require_tenant_membership!, only: [:match]
    before_action -> { require_feature!(:ai_matching) }, only: [:match]

    # POST /ai/match
    def match
      if params[:query].blank?
        return render json: { error: "query parameter is required" }, status: :unprocessable_entity
      end

      experts = Ai::MatchExpertsService.match(
        query: params[:query],
        tenant: current_tenant,
        limit: (params[:limit] || 5).to_i
      )

      # Render matching users
      users = User.where(id: experts.map(&:user_id))
      render json: UserBlueprint.render_as_hash(users)
    end
  end
end
