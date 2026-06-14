class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.references :reviewee, foreign_key: { to_table: :users }
      t.references :reviewable, polymorphic: true, null: false
      t.integer :rating, null: false
      t.text :content

      t.timestamps
    end

    add_index :reviews, [:tenant_id, :reviewable_type, :reviewable_id]
  end
end
