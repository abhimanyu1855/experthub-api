# frozen_string_literal: true

class RescheduleRequestsController < ApplicationController
  # POST /bookings/:id/reschedule_requests
  def create
    booking = current_tenant.bookings.find(params[:id])
    
    # Check if user is participant of the booking
    unless booking.client_id == current_user.id || booking.expert_id == current_user.id || current_membership.operator?
      return render json: { error: "Not authorized to reschedule this booking" }, status: :forbidden
    end

    reschedule_request = RescheduleRequest.new(reschedule_params)
    reschedule_request.tenant = current_tenant
    reschedule_request.booking = booking
    reschedule_request.requested_by = current_user
    reschedule_request.old_start_time = booking.start_time
    reschedule_request.old_end_time = booking.end_time
    reschedule_request.status = "pending"
    reschedule_request.expires_at = booking.start_time

    if reschedule_request.save
      render json: reschedule_request, status: :created
    else
      render json: { errors: reschedule_request.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /reschedule_requests/:id/accept
  def accept
    reschedule_request = RescheduleRequest.joins(:booking).where(bookings: { tenant_id: current_tenant.id }).find(params[:id])
    booking = reschedule_request.booking

    # Only the OTHER party can accept (or operator)
    if reschedule_request.requested_by_id == current_user.id && !current_membership.operator?
      return render json: { error: "Cannot accept your own reschedule request" }, status: :forbidden
    end

    unless booking.client_id == current_user.id || booking.expert_id == current_user.id || current_membership.operator?
      return render json: { error: "Not authorized to accept this request" }, status: :forbidden
    end

    if reschedule_request.accept!
      render json: reschedule_request
    else
      render json: { errors: reschedule_request.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /reschedule_requests/:id/reject
  def reject
    reschedule_request = RescheduleRequest.joins(:booking).where(bookings: { tenant_id: current_tenant.id }).find(params[:id])
    booking = reschedule_request.booking

    if reschedule_request.requested_by_id == current_user.id && !current_membership.operator?
      return render json: { error: "Cannot reject your own reschedule request" }, status: :forbidden
    end

    unless booking.client_id == current_user.id || booking.expert_id == current_user.id || current_membership.operator?
      return render json: { error: "Not authorized to reject this request" }, status: :forbidden
    end

    if reschedule_request.reject!
      render json: reschedule_request
    else
      render json: { errors: reschedule_request.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def reschedule_params
    params.require(:reschedule_request).permit(:new_start_time, :new_end_time, :reason)
  end
end
