class AddPrestigeFieldsToExpertProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :expert_profiles, :press_links, :jsonb, default: []
    add_column :expert_profiles, :credentials, :jsonb, default: []
    add_column :expert_profiles, :intro_video_url, :string

    add_reference :subscription_plans, :expert_profile, null: true, foreign_key: true
  end
end
