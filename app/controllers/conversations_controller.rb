# frozen_string_literal: true

class ConversationsController < ApplicationController
  # GET /conversations
  def index
    conversations = current_user.conversations
                                .where(tenant: current_tenant)
                                .includes(:users, :messages)
                                .order(created_at: :desc)

    res = conversations.map do |c|
      last_msg = c.messages.max_by(&:created_at)
      {
        id: c.id,
        created_at: c.created_at,
        participants: c.users.map { |u| { id: u.id, name: u.displayed_name, email: u.email } },
        last_message: last_msg ? { content: last_msg.content, created_at: last_msg.created_at } : nil
      }
    end

    render json: res
  end

  # POST /conversations
  def create
    unless params[:recipient_id].present?
      return render json: { error: "recipient_id is required" }, status: :unprocessable_entity
    end

    recipient = User.find(params[:recipient_id])
    unless recipient.memberships.where(tenant: current_tenant).exists?
      return render json: { error: "Recipient is not a member of this tenant" }, status: :forbidden
    end

    conversation = Conversation.between(current_user.id, recipient.id, tenant: current_tenant)
    
    render json: {
      id: conversation.id,
      participants: conversation.users.map { |u| { id: u.id, name: u.displayed_name } }
    }, status: :created
  end
end
