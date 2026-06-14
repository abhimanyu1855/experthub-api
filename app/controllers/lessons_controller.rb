# frozen_string_literal: true

class LessonsController < ApplicationController
  before_action :require_expert!, only: [:create]

  # POST /lessons
  def create
    course = current_tenant.courses.find(params[:lesson][:course_id])
    lesson = course.lessons.new(lesson_params)
    lesson.sort_priority = course.lessons.maximum(:sort_priority).to_i + 1

    if lesson.save
      render json: lesson, status: :created
    else
      render json: { errors: lesson.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /lessons/:id/quiz
  def quiz
    lesson = Lesson.find(params[:id])
    quiz = lesson.quiz
    if quiz
      render json: quiz.as_json(include: { questions: { include: :options } })
    else
      render json: { error: "No quiz for this lesson" }, status: :not_found
    end
  end

  # POST /lessons/:id/complete
  def complete
    lesson = Lesson.find(params[:id])
    enrollment = current_user.enrollments.find_by!(course_id: lesson.course_id)

    progress = enrollment.progresses.find_or_initialize_by(lesson: lesson)
    progress.completed_at = Time.current if progress.new_record?

    if progress.save
      render json: { 
        success: true, 
        enrollment_status: enrollment.reload.status, 
        certificate: enrollment.certificate 
      }
    else
      render json: { errors: progress.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /lessons/:id/quiz/submit
  def submit_quiz
    lesson = Lesson.find(params[:id])
    quiz = lesson.quiz
    return render json: { error: "No quiz for this lesson" }, status: :unprocessable_entity unless quiz

    submitted_answers = params[:answers] || {} # format: { "question_id" => "option_id" }

    passed = true
    quiz.questions.each do |q|
      selected_option_id = submitted_answers[q.id.to_s]
      correct_option = q.options.find_by(is_correct: true)

      if correct_option && correct_option.id.to_s != selected_option_id.to_s
        passed = false
        break
      end
    end

    if passed
      # Automatically complete the lesson
      enrollment = current_user.enrollments.find_by!(course_id: lesson.course_id)
      progress = enrollment.progresses.find_or_initialize_by(lesson: lesson)
      progress.completed_at = Time.current if progress.new_record?

      if progress.save
        render json: { 
          passed: true, 
          enrollment_status: enrollment.reload.status, 
          certificate: enrollment.certificate 
        }
      else
        render json: { errors: progress.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { passed: false, message: "Incorrect answers. Please try again." }
    end
  end

  def lesson_params
    params.require(:lesson).permit(:title, :description, :video_url, :course_id, :sort_priority)
  end
end
