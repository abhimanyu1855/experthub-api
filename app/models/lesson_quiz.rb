# frozen_string_literal: true

class LessonQuiz < ApplicationRecord
  belongs_to :lesson
  has_many :questions, class_name: "QuizQuestion", foreign_key: :lesson_quiz_id, dependent: :destroy

  validates :title, presence: true
end
