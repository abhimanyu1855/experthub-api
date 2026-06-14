# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :set_conversation

  # GET /conversations/:conversation_id/messages
  def index
    messages = @conversation.messages.includes(:sender).order(created_at: :asc)
    
    res = messages.map do |m|
      {
        id: m.id,
        content: m.content,
        created_at: m.created_at,
        sender: { id: m.sender_id, name: m.sender.displayed_name }
      }
    end

    render json: res
  end

  # POST /conversations/:conversation_id/messages
  def create
    message = @conversation.messages.new(message_params)
    message.sender = current_user

    if message.save
      render json: {
        id: message.id,
        content: message.content,
        created_at: message.created_at,
        sender: { id: current_user.id, name: current_user.displayed_name }
      }, status: :created
    else
      render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    @conversation = current_user.conversations.where(tenant: current_tenant).find(params[:conversation_id])
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
