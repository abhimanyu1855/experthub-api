# frozen_string_literal: true

class AddTranslationsToCategoriesAndPages < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :translations, :jsonb, default: {}, null: false
    add_column :pages, :translations, :jsonb, default: {}, null: false
  end
end
