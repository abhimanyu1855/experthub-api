# frozen_string_literal: true

class AddSupportedLocalesToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :supported_locales, :jsonb, default: ["en"], null: false
  end
end
