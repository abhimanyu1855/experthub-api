# frozen_string_literal: true

class NotificationsController < ApplicationController
  # GET /notifications
  def index
    notifications = current_user.notifications.where(tenant: current_tenant).unread.order(created_at: :desc)
    render json: notifications
  end

  # GET /notifications/unread_count
  def unread_count
    count = current_tenant.notifications.where(user: current_user, read_at: nil).count
    render json: { count: count }
  end

  # POST /notifications/:id/read
  def read
    notification = current_user.notifications.where(tenant: current_tenant).find(params[:id])
    notification.mark_as_read!
    render json: { success: true }
  end
end
