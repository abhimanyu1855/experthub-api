# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show]
  skip_before_action :require_tenant_membership!, only: [:show]

  # GET /pages/:slug
  def show
    page = current_tenant.pages.published.find_by!(slug: params[:slug])
    render json: page
  end
end
