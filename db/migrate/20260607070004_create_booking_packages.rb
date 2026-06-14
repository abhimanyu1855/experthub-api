class CreateBookingPackages < ActiveRecord::Migration[8.1]
  def change
    create_table :booking_packages do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :expert_profile, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :price_cents, null: false, default: 0
      t.string :currency, null: false, default: "USD"
      t.integer :booking_count, null: false, default: 5

      t.timestamps
    end

    create_table :package_purchases do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :booking_package, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :remaining_bookings, null: false

      t.timestamps
    end
  end
end
