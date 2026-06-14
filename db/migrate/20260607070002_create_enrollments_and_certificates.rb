class CreateEnrollmentsAndCertificates < ActiveRecord::Migration[8.1]
  def change
    create_table :enrollments do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :enrollments, [:user_id, :course_id], unique: true

    create_table :lesson_progresses do |t|
      t.references :enrollment, null: false, foreign_key: true
      t.references :lesson, null: false, foreign_key: true
      t.datetime :completed_at

      t.timestamps
    end

    add_index :lesson_progresses, [:enrollment_id, :lesson_id], unique: true

    create_table :certificates do |t|
      t.references :enrollment, null: false, foreign_key: true, index: { unique: true }
      t.string :certificate_code, null: false
      t.datetime :issued_at, null: false

      t.timestamps
    end

    add_index :certificates, :certificate_code, unique: true
  end
end
