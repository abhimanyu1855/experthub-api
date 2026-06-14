# Ported from mytin: categories table (hierarchical, tenant-scoped)
class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :categories }  # hierarchy
      t.string  :name, null: false
      t.string  :slug
      t.integer :sort_priority, default: 0
      t.string  :category_type, default: "service"  # service, course, session

      t.timestamps
    end

    add_index :categories, [:tenant_id, :slug], unique: true
    add_index :categories, [:tenant_id, :category_type, :sort_priority]
  end
end
