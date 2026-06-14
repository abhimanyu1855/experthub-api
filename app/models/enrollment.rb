# frozen_string_literal: true

class Enrollment < ApplicationRecord
  belongs_to :tenant
  belongs_to :course
  belongs_to :user
  has_many :progresses, class_name: "LessonProgress", dependent: :destroy
  has_one  :certificate, dependent: :destroy

  validates :status, presence: true, inclusion: { in: %w[active completed] }
  validates :user_id, uniqueness: { scope: :course_id }

  def check_completion!
    total_lessons = course.lessons.count
    completed_lessons = progresses.count

    if completed_lessons >= total_lessons && total_lessons > 0 && status != "completed"
      transaction do
        update!(status: "completed")
        issue_certificate!
      end
    end
  end

  private

  def issue_certificate!
    return if certificate.present?

    code = "CERT-#{SecureRandom.hex(6).upcase}"
    create_certificate!(
      certificate_code: code,
      issued_at: Time.current
    )
  end
end
