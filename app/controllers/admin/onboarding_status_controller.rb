# frozen_string_literal: true

class Admin::OnboardingStatusController < ApplicationController
  before_action :require_operator!

  STEPS = %w[name brand payments domain landing experts]

  # GET /admin/onboarding_status
  def show
    # Ensure all steps exist for the tenant
    STEPS.each do |step_id|
      current_tenant.tenant_setup_steps.find_or_create_by!(step_id: step_id) do |s|
        s.completed = false
        s.active = (step_id == "name")
      end
    end

    render json: {
      steps: current_tenant.tenant_setup_steps.order(:id).map { |s|
        {
          id: s.step_id,
          completed: s.completed,
          active: s.active
        }
      }
    }
  end

  # PATCH /admin/onboarding_status/:step_id
  def update
    step = current_tenant.tenant_setup_steps.find_by!(step_id: params[:step_id])
    if step.update(completed: params[:completed] == true || params[:completed] == "true", active: params[:active] == true || params[:active] == "true")
      # Automatically set next step active if completed
      if step.completed
        current_idx = STEPS.index(step.step_id)
        if current_idx && current_idx < STEPS.length - 1
          next_step_id = STEPS[current_idx + 1]
          next_step = current_tenant.tenant_setup_steps.find_by(step_id: next_step_id)
          next_step&.update(active: true)
        end
      end
      render json: { step: { id: step.step_id, completed: step.completed, active: step.active } }
    else
      render json: { error: step.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end
end
