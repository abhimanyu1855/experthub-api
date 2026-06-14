# frozen_string_literal: true

class ExpertMailer < ApplicationMailer
  def application_approved(user, tenant)
    @user = user
    @tenant = tenant
    mail(to: @user.email, subject: "Your expert application has been approved!")
  end

  def application_rejected(user, tenant, reason)
    @user = user
    @tenant = tenant
    @reason = reason.presence || "No specific reason provided."
    mail(to: @user.email, subject: "Update on your expert application")
  end
end
