# frozen_string_literal: true

module Ai
  class TriageController < ApplicationController
    skip_before_action :authenticate_user!, only: [:create, :chat]
    skip_before_action :require_tenant_membership!, only: [:create, :chat]
    before_action -> { require_feature!(:triage_chatbot) }, only: [:create, :chat]

    # POST /ai/triage_sessions
    def create
      token = SecureRandom.hex(16)
      
      # Optional association with logged-in user
      associated_user = warden.authenticate(scope: :user)

      session = AiTriageSession.create!(
        tenant: current_tenant,
        user: associated_user,
        session_token: token,
        status: "active",
        messages: [{ role: "assistant", content: "Hello! How can I help you find the right expert today?" }]
      )

      render json: session, status: :created
    end

    # POST /ai/triage_sessions/:session_token/chat
    def chat
      session = AiTriageSession.find_by!(session_token: params[:session_token], tenant: current_tenant)
      
      unless params[:message].present?
        return render json: { error: "message parameter is required" }, status: :unprocessable_entity
      end

      result = Ai::TriageChatService.send_message(
        session: session,
        content: params[:message]
      )

      render json: result
    end
  end
end
