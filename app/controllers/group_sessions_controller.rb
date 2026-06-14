# frozen_string_literal: true

class GroupSessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  skip_before_action :require_tenant_membership!, only: [:index, :show]
  before_action :require_expert!, only: [:create]
  before_action -> { require_feature!(:group_sessions) }, only: [:create]

  # GET /group_sessions
  def index
    if params[:my_sessions] == "true"
      authenticate_user!
      require_tenant_membership!
      require_expert!
      sessions = current_tenant.group_sessions.where(expert_profile_id: current_user.expert_profile&.id)
      render json: sessions.as_json(include: {
        attendances: { include: { user: { only: [:id, :email, :given_name, :family_name, :display_name] } } }
      })
    else
      sessions = current_tenant.group_sessions.where("start_time > ?", Time.current)
      render json: sessions.as_json(
        include: { expert_profile: { include: { user: { only: [:given_name, :family_name, :display_name] } } } },
        methods: [:registered_count, :full?]
      )
    end
  end

  # GET /group_sessions/:id
  def show
    session = current_tenant.group_sessions.find(params[:id])
    render json: session
  end

  # POST /group_sessions
  def create
    session = current_tenant.group_sessions.new(group_session_params)
    session.expert_profile = current_user.expert_profile

    # Mock video room generation for group session
    session.video_room_url = "https://daily.co/group-session-#{SecureRandom.hex(4)}"

    if session.save
      render json: session, status: :created
    else
      render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /group_sessions/:id/register
  def register
    session = current_tenant.group_sessions.find(params[:id])
    
    attendance = session.attendances.new(user: current_user, status: "registered")
    if attendance.save
      # If payment is needed, we'd trigger Razorpay/Stripe charges here. For MVP, we auto-register.
      render json: attendance, status: :created
    else
      render json: { errors: attendance.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def group_session_params
    params.require(:group_session).permit(:title, :description, :start_time, :end_time, :price_cents, :currency, :max_participants)
  end
end
