# frozen_string_literal: true

class CategoriesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  skip_before_action :require_tenant_membership!, only: [:index]
  before_action :require_operator!, only: [:create, :update, :destroy]

  # GET /categories
  def index
    categories = current_tenant.categories.order(sort_priority: :asc, name: :asc)
    render json: CategoryBlueprint.render_as_hash(categories)
  end

  # POST /categories
  def create
    category = current_tenant.categories.new(category_params)
    if category.save
      render json: CategoryBlueprint.render_as_hash(category), status: :created
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /categories/:id
  def update
    category = current_tenant.categories.find(params[:id])
    if category.update(category_params)
      render json: CategoryBlueprint.render_as_hash(category)
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /categories/:id
  def destroy
    category = current_tenant.categories.find(params[:id])
    category.destroy!
    head :no_content
  end

  private

  def category_params
    params.require(:category).permit(:name, :slug, :parent_id, :sort_priority, :category_type)
  end
end
