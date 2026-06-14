# frozen_string_literal: true

class GroupSession < ApplicationRecord
  belongs_to :tenant
  belongs_to :expert_profile
  has_many :attendances, class_name: "SessionAttendance", dependent: :destroy
  has_many :users, through: :attendances

  validates :title, presence: true
  validates :start_time, :end_time, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :max_participants, numericality: { only_integer: true, greater_than: 0 }
  validate :end_time_after_start_time

  def registered_count
    attendances.count
  end

  def full?
    registered_count >= max_participants
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
