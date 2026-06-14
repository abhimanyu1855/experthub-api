# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: "User"

  # Encrypt content at rest — only participants can decrypt via the API.
  # The server can still read it for AI features (summaries, smart replies).
  encrypts :content

  validates :content, presence: true

  after_create_commit :broadcast_to_participants
  after_create_commit :notify_recipient

  private

  def broadcast_to_participants
    ActionCable.server.broadcast(
      "conversation_#{conversation_id}",
      {
        id: id,
        conversation_id: conversation_id,
        content: content,
        created_at: created_at.iso8601,
        sender: { id: sender_id, name: sender.displayed_name }
      }
    )
  end

  def notify_recipient
    recipient_participation = conversation.participations.where.not(user_id: sender_id).first
    return unless recipient_participation

    Notification.create!(
      tenant: conversation.tenant,
      user_id: recipient_participation.user_id,
      notification_type: "new_message",
      data: {
        conversation_id: conversation_id,
        message_id: id,
        sender_id: sender_id,
        sender_name: sender.displayed_name,
        snippet: content.truncate(60)
      }
    )
  end
end
