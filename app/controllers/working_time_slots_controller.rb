# frozen_string_literal: true

class WorkingTimeSlotsController < ApplicationController
  before_action :require_expert!

  # GET /working_time_slots
  def index
    slots = current_user.expert_profile.working_time_slots.order(:week_day, :from_time)
    render json: slots
  end

  # POST /working_time_slots
  def create
    profile = current_user.expert_profile
    return render json: { error: "Expert profile not found" }, status: :unprocessable_entity unless profile

    slot = profile.working_time_slots.build(
      week_day: params[:week_day],
      from_time: params[:from_time],
      till_time: params[:till_time],
      is_active: true
    )

    if slot.save
      render json: slot, status: :created
    else
      render json: { errors: slot.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /working_time_slots/:id
  def destroy
    slot = current_user.expert_profile.working_time_slots.find(params[:id])
    slot.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Slot not found" }, status: :not_found
  end
end
