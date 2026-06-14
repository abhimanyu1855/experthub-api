class CreateExpertApplicationsAndSetupSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :expert_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.jsonb :application_data, default: {}, null: false

      t.timestamps
    end

    create_table :tenant_setup_steps do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :step_id, null: false
      t.boolean :completed, default: false, null: false
      t.boolean :active, default: false, null: false

      t.timestamps
    end
    add_index :tenant_setup_steps, [:tenant_id, :step_id], unique: true
  end
end
