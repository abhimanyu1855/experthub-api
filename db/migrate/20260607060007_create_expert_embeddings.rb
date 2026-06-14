class CreateExpertEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_table :expert_embeddings do |t|
      t.references :expert_profile, null: false, foreign_key: true, index: { unique: true }
      t.vector :embedding, limit: 1536, null: false
      t.string :content_hash, null: false

      t.timestamps
    end
  end
end
