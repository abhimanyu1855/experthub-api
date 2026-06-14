# frozen_string_literal: true

class Conversation < ApplicationRecord
  belongs_to :tenant
  has_many :participations, class_name: "ConversationParticipation", dependent: :destroy
  has_many :users, through: :participations
  has_many :messages, dependent: :destroy

  # Finds or creates a conversation between two users on a tenant
  def self.between(user1_id, user2_id, tenant:)
    # Find active conversation involving both users
    conversation = tenant.conversations
                         .joins(:participations)
                         .where(conversation_participations: { user_id: [user1_id, user2_id] })
                         .group("conversations.id")
                         .having("COUNT(DISTINCT conversation_participations.user_id) = 2")
                         .first

    return conversation if conversation

    transaction do
      conv = create!(tenant: tenant)
      conv.participations.create!(user_id: user1_id)
      conv.participations.create!(user_id: user2_id)
      conv
    end
  end
end
