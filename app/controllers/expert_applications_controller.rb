# frozen_string_literal: true

class ExpertApplicationsController < ApplicationController
  # POST /expert_applications
  def create
    # Find or initialize application for the current user in this tenant
    application = current_tenant.expert_applications.find_or_initialize_by(user: current_user)
    application.status = "pending"
    application.application_data = params[:application] || {}

    if application.save
      render json: { message: "Application submitted successfully.", application: application }, status: :created
    else
      render json: { errors: application.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
