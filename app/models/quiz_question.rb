# frozen_string_literal: true

class QuizQuestion < ApplicationRecord
  belongs_to :quiz, class_name: "LessonQuiz", foreign_key: :lesson_quiz_id
  has_many :options, class_name: "QuizOption", dependent: :destroy

  validates :question_text, presence: true
end
