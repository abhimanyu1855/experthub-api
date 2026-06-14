class CreateAiTriageSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_triage_sessions do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :session_token, null: false
      t.jsonb :messages, default: [], null: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :ai_triage_sessions, :session_token, unique: true
  end
end
