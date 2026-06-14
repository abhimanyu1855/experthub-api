# frozen_string_literal: true

class WorkingTimeSlot < ApplicationRecord
  belongs_to :expert_profile

  validates :week_day, presence: true, inclusion: { in: 1..7 }
  validates :from_time, :till_time, presence: true

  scope :for_day, ->(day) { where(week_day: day, is_active: true) }
  scope :active, -> { where(is_active: true) }
end
