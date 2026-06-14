class CreateSessionSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :session_summaries do |t|
      t.references :booking, null: false, foreign_key: true, index: { unique: true }
      t.text :summary, null: false
      t.jsonb :action_items, default: [], null: false
      t.text :transcript

      t.timestamps
    end
  end
end
