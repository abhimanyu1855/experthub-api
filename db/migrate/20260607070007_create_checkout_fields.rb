class CreateCheckoutFields < ActiveRecord::Migration[8.1]
  def change
    create_table :checkout_fields do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :field_name, null: false
      t.string :field_type, null: false # e.g. "text", "number", "select"
      t.boolean :required, null: false, default: false
      t.jsonb :options, default: [], null: false

      t.timestamps
    end

    create_table :checkout_field_values do |t|
      t.references :checkout_field, null: false, foreign_key: true
      t.references :booking, null: false, foreign_key: true
      t.text :value, null: false

      t.timestamps
    end

    add_index :checkout_field_values, [:checkout_field_id, :booking_id], unique: true
  end
end
