# frozen_string_literal: true

class CategoryBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :slug, :parent_id, :sort_priority, :category_type
end
