# frozen_string_literal: true

class SimpleUserBlueprint < Blueprinter::Base
  identifier :id

  fields :email, :given_name, :family_name, :display_name, :phone_number, :avatar_url, :description, :created_at
end
