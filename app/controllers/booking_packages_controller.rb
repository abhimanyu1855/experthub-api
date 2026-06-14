# frozen_string_literal: true

class BookingPackagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  skip_before_action :require_tenant_membership!, only: [:index]
  before_action :require_expert!, only: [:create]
  before_action -> { require_feature!(:booking_packages) }, only: [:create]

  # GET /booking_packages
  def index
    packages = current_tenant.booking_packages
    render json: packages
  end

  # POST /booking_packages
  def create
    package = current_tenant.booking_packages.new(package_params)
    package.expert_profile = current_user.expert_profile

    if package.save
      render json: package, status: :created
    else
      render json: { errors: package.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /booking_packages/:id/purchase
  def purchase
    package = current_tenant.booking_packages.find(params[:id])
    
    purchase_record = current_tenant.package_purchases.new(
      booking_package: package,
      user: current_user,
      remaining_bookings: package.booking_count
    )

    if purchase_record.save
      render json: purchase_record, status: :created
    else
      render json: { errors: purchase_record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def package_params
    params.require(:booking_package).permit(:title, :description, :price_cents, :currency, :booking_count)
  end
end
