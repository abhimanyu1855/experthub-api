# frozen_string_literal: true

class ReviewsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  skip_before_action :require_tenant_membership!, only: [:index]

  # GET /services/:service_id/reviews or GET /reviews
  def index
    if params[:expert_profile_id].present?
      expert = current_tenant.expert_profiles.find(params[:expert_profile_id])
      reviews = Review.where(reviewee: expert.user)
      render json: reviews.as_json(include: { reviewer: { only: [:given_name, :family_name, :display_name] } })
    elsif params[:service_id].present?
      service = current_tenant.services.find(params[:service_id])
      reviews = Review.where(reviewable: service)
      render json: reviews.as_json(include: { reviewer: { only: [:given_name, :family_name, :display_name] } })
    else
      render json: []
    end
  end

  # POST /services/:service_id/reviews
  def create
    service = current_tenant.services.find(params[:service_id])
    
    review = Review.new(review_params)
    review.tenant = current_tenant
    review.reviewer = current_user
    review.reviewable = service
    # The reviewee is the expert of the service
    review.reviewee = service.expert_profile.user

    if review.save
      render json: review, status: :created
    else
      render json: { errors: review.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def review_params
    params.require(:review).permit(:rating, :content)
  end
end
