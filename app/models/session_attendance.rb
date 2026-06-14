# frozen_string_literal: true

class SessionAttendance < ApplicationRecord
  belongs_to :group_session
  belongs_to :user

  validates :status, presence: true, inclusion: { in: %w[registered attended canceled] }
  validates :user_id, uniqueness: { scope: :group_session_id }
  validate :session_not_full, on: :create

  private

  def session_not_full
    return unless group_session
    # Count current active registered/attended attendees
    current_attendee_count = group_session.attendances.where(status: %w[registered attended]).count
    if current_attendee_count >= group_session.max_participants
      errors.add(:base, "This group session is already full")
    end
  end
end
