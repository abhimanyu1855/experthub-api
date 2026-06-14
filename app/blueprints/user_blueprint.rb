# frozen_string_literal: true

class UserBlueprint < Blueprinter::Base
  identifier :id

  fields :email, :given_name, :family_name, :display_name, :phone_number, :avatar_url, :description, :created_at

  association :expert_profile, blueprint: ExpertProfileBlueprint, view: :normal

  view :normal do
    fields :email, :given_name, :family_name, :display_name
  end
end
