# frozen_string_literal: true

class LessonProgress < ApplicationRecord
  belongs_to :enrollment
  belongs_to :lesson

  validates :lesson_id, uniqueness: { scope: :enrollment_id }

  after_create_commit :check_course_completion

  private

  def check_course_completion
    enrollment.check_completion!
  end
end
