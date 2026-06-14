# frozen_string_literal: true

# Streams new messages to both participants of a conversation in real time.
# Each conversation gets its own stream: "conversation_<id>".
# Only participants who are members of the correct tenant can subscribe.
class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = find_conversation
    if conversation
      stream_from "conversation_#{conversation.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  private

  def find_conversation
    return nil unless params[:conversation_id]

    conversation = current_user.conversations
                               .where(tenant: current_tenant)
                               .find_by(id: params[:conversation_id])
    return nil unless conversation

    # Ensure the user is a participant in this conversation
    conversation.participations.where(user: current_user).exists? ? conversation : nil
  end
end
