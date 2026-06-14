class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.text :content, null: false
      t.boolean :is_published, null: false, default: true

      t.timestamps
    end

    add_index :pages, [:tenant_id, :slug], unique: true
  end
end
