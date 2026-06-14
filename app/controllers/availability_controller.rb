# frozen_string_literal: true

class AvailabilityController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  skip_before_action :require_tenant_membership!, only: [:index]

  # GET /services/:service_id/slots?date=YYYY-MM-DD&timezone_offset=0
  def index
    service = current_tenant.services.find(params[:service_id])
    
    begin
      date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    rescue Date::Error
      return render json: { error: "Invalid date format, use YYYY-MM-DD" }, status: :unprocessable_entity
    end

    timezone_offset = (params[:timezone_offset] || 0).to_i

    slots = AvailabilityService.available_slots(
      service: service,
      date: date,
      timezone_offset: timezone_offset
    )

    render json: { slots: slots }
  end
end
