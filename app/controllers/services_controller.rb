# frozen_string_literal: true

class ServicesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  skip_before_action :require_tenant_membership!, only: [:index, :show]
  before_action :require_expert!, only: [:create, :update, :destroy]

  # GET /services (Public discovery)
  def index
    if params[:my_services] == "true"
      authenticate_user!
      require_tenant_membership!
      require_expert!
      services = current_tenant.services.where(expert_profile_id: current_user.expert_profile&.id)
    else
      services = current_tenant.services.active_approved
      services = services.by_category(params[:category_id]) if params[:category_id].present?
      services = services.where(expert_profile_id: params[:expert_profile_id]) if params[:expert_profile_id].present?
    end
    
    # Simple search if query present
    if params[:q].present?
      services = services.where("title ILIKE ? OR description ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
    end

    services = services.includes(:expert_profile, :category)
    render json: ServiceBlueprint.render_as_hash(services)
  end

  # GET /services/:id
  def show
    service = current_tenant.services.find(params[:id])
    render json: ServiceBlueprint.render_as_hash(service)
  end

  # POST /services
  def create
    service = current_tenant.services.new(service_params)
    service.expert_profile = current_user.expert_profile

    # Determine approval status based on tenant settings
    if current_tenant.require_expert_approval?
      service.approval_status = :pending_review
    else
      service.approval_status = :approved
    end

    if service.save
      render json: ServiceBlueprint.render_as_hash(service), status: :created
    else
      render json: { errors: service.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /services/:id
  def update
    service = current_user.expert_profile.services.find(params[:id])

    if service.update(service_params)
      render json: ServiceBlueprint.render_as_hash(service)
    else
      render json: { errors: service.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /services/:id
  def destroy
    service = current_user.expert_profile.services.find(params[:id])
    service.destroy
    head :no_content
  end

  private

  def service_params
    params.require(:service).permit(:title, :description, :price_cents, :currency, :duration_minutes, :slot_interval_minutes, :booking_buffer_minutes, :allow_multiple_bookings, :max_concurrent_bookings, :category_id)
  end
end
