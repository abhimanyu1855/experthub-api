# frozen_string_literal: true

class QuizOption < ApplicationRecord
  belongs_to :question, class_name: "QuizQuestion", foreign_key: :quiz_question_id

  validates :option_text, presence: true
end
