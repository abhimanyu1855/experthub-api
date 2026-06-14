# frozen_string_literal: true

class AiTriageSession < ApplicationRecord
  belongs_to :tenant
  belongs_to :user, optional: true

  validates :session_token, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[active triaged closed] }
  validates :messages, presence: true
end
