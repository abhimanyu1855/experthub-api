# frozen_string_literal: true

class PromoCodesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:validate]
  skip_before_action :require_tenant_membership!, only: [:validate]
  before_action :require_operator!, only: [:index, :create, :destroy]
  before_action -> { require_feature!(:promo_codes) }, only: [:index, :create, :destroy]

  # GET /promo_codes
  def index
    promo_codes = current_tenant.promo_codes.order(created_at: :desc)
    render json: promo_codes.as_json(methods: [:expired?, :max_redemptions_reached?, :valid_for_use?])
  end

  # POST /promo_codes
  def create
    promo_code = current_tenant.promo_codes.new(promo_code_params)
    if promo_code.save
      render json: promo_code.as_json(methods: [:expired?, :max_redemptions_reached?, :valid_for_use?]), status: :created
    else
      render json: { errors: promo_code.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /promo_codes/:id
  def destroy
    promo_code = current_tenant.promo_codes.find(params[:id])
    promo_code.destroy!
    head :no_content
  end

  # POST /promo_codes/validate
  def validate
    code_string = params[:code].to_s.strip
    price_cents = params[:price_cents].to_i

    promo_code = current_tenant.promo_codes.active.find_by(code: code_string)
    if promo_code.nil?
      return render json: { valid: false, error: "Promo code not found or inactive" }, status: :not_found
    end

    unless promo_code.valid_for_use?
      return render json: { valid: false, error: "Promo code has expired or reached maximum uses" }, status: :unprocessable_entity
    end

    discount_cents = promo_code.calculate_discount(price_cents)
    render json: {
      valid: true,
      code: promo_code.code,
      discount_type: promo_code.discount_type,
      discount_value: promo_code.discount_value.to_f,
      discount_cents: discount_cents,
      final_price_cents: price_cents - discount_cents
    }
  end

  private

  def promo_code_params
    params.require(:promo_code).permit(:code, :discount_type, :discount_value, :max_redemptions, :expires_at)
  end
end
