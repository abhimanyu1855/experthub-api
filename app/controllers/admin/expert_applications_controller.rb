# frozen_string_literal: true

class Admin::ExpertApplicationsController < ApplicationController
  before_action :require_operator!

  # GET /admin/expert_applications
  def index
    applications = current_tenant.expert_applications.order(created_at: :desc)
    
    if params[:status].present?
      applications = applications.where(status: params[:status])
    end

    # Render with custom blueprint or simple JSON
    render json: applications.as_json(include: { user: { only: [:id, :email, :given_name, :family_name, :display_name] } })
  end

  # POST /admin/expert_applications/:id/approve
  def approve
    application = current_tenant.expert_applications.find(params[:id])

    unless current_tenant.within_expert_limit?
      return render json: {
        error: "Expert limit reached for your current plan (#{current_tenant.plan}). Upgrade to add more experts.",
        current_plan: current_tenant.plan,
        upgrade_required: true
      }, status: :payment_required
    end

    ActiveRecord::Base.transaction do
      application.update!(status: "approved")
      
      # Update the User membership to expert
      membership = application.user.memberships.find_or_initialize_by(tenant: current_tenant)
      membership.update!(role: "expert", status: "active")
      
      # Create or update ExpertProfile
      expert_profile = application.user.expert_profile || ExpertProfile.new(user: application.user, tenant: current_tenant)
      
      initial_credentials = []
      if application.application_data["credentials"].present?
        initial_credentials << { name: "Verification", details: application.application_data["credentials"] }
      end

      initial_press = []
      if application.application_data["linkedin"].present?
        initial_press << { name: "LinkedIn", url: application.application_data["linkedin"] }
      end
      if application.application_data["website"].present?
        initial_press << { name: "Website", url: application.application_data["website"] }
      end

      expert_profile.update!(
        tenant: current_tenant,
        specialization: application.application_data["headline"] || application.application_data["expertise"] || "Expert",
        bio: application.application_data["bio"] || "",
        approval_status: "approved",
        credentials: initial_credentials,
        press_links: initial_press
      )
    end

    ExpertMailer.application_approved(application.user, current_tenant).deliver_later

    render json: { message: "Application approved successfully.", application: application }
  end

  # POST /admin/expert_applications/:id/reject
  def reject
    application = current_tenant.expert_applications.find(params[:id])
    reason = params[:reason].to_s.strip
    application.update!(status: "rejected")

    ExpertMailer.application_rejected(application.user, current_tenant, reason).deliver_later

    render json: { message: "Application rejected.", application: application }
  end
end
