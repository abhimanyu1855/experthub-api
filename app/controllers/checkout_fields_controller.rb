# frozen_string_literal: true

class CheckoutFieldsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  skip_before_action :require_tenant_membership!, only: [:index]
  before_action :require_operator!, only: [:create, :destroy]

  # GET /checkout_fields
  def index
    fields = current_tenant.checkout_fields
    render json: fields
  end

  # POST /checkout_fields
  def create
    field = current_tenant.checkout_fields.new(field_params)

    if field.save
      render json: field, status: :created
    else
      render json: { errors: field.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /checkout_fields/:id
  def destroy
    field = current_tenant.checkout_fields.find(params[:id])
    field.destroy!
    head :no_content
  end

  private

  def field_params
    params.require(:checkout_field).permit(:field_name, :field_type, :required, options: [])
  end
end
