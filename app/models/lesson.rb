# frozen_string_literal: true

class Lesson < ApplicationRecord
  belongs_to :course
  has_one :quiz, class_name: "LessonQuiz", dependent: :destroy

  validates :title, presence: true
  validates :sort_priority, presence: true
end
