# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :tenant
  belongs_to :user

  validates :notification_type, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }

  after_create_commit :broadcast_to_user

  def mark_as_read!
    update!(read_at: Time.current)
  end

  private

  def broadcast_to_user
    NotificationChannel.broadcast_to(
      user,
      {
        id: id,
        notification_type: notification_type,
        data: data,
        created_at: created_at,
        read: false
      }
    )
  end
end
