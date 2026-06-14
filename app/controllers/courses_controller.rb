# frozen_string_literal: true

class CoursesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  skip_before_action :require_tenant_membership!, only: [:index, :show]
  before_action :require_expert!, only: [:create, :update]
  before_action -> { require_feature!(:courses) }, only: [:create]

  # GET /courses
  def index
    if params[:my_courses] == "true"
      authenticate_user!
      require_tenant_membership!
      require_expert!
      courses = current_tenant.courses.where(expert_profile_id: current_user.expert_profile&.id)
      render json: courses.as_json(include: {
        enrollments: { include: { user: { only: [:id, :email, :given_name, :family_name, :display_name] } } }
      })
    else
      courses = current_tenant.courses.active_approved
      render json: courses.as_json(
        include: { expert_profile: { include: { user: { only: [:given_name, :family_name, :display_name] } } } },
        methods: [:enrollments_count]
      )
    end
  end

  # GET /courses/:id
  def show
    course = current_tenant.courses.active_approved.includes(lessons: :quiz).find(params[:id])
    enrollment = current_user ? current_user.enrollments.find_by(course: course) : nil
    
    course_json = course.as_json(include: { lessons: { include: :quiz } })
    if enrollment
      course_json["enrollment"] = enrollment.as_json(include: :progresses)
    end
    
    render json: course_json
  end

  # POST /courses
  def create
    course = current_tenant.courses.new(course_params)
    course.expert_profile = current_user.expert_profile
    course.approval_status = :approved # Auto-approve for easy onboarding

    if course.save
      render json: course, status: :created
    else
      render json: { errors: course.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /courses/:id
  def update
    course = current_tenant.courses.find(params[:id])
    if course.update(course_params)
      render json: course
    else
      render json: { errors: course.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /courses/:id/enroll
  def enroll
    course = current_tenant.courses.find(params[:id])
    enrollment = current_tenant.enrollments.new(course: course, user: current_user, status: "active")

    if enrollment.save
      render json: enrollment, status: :created
    else
      render json: { errors: enrollment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def course_params
    params.require(:course).permit(:title, :description, :price_cents, :currency, :is_active)
  end
end
