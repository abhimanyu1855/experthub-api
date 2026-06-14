class CreateCoursesAndLessons < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :expert_profile, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :price_cents, null: false, default: 0
      t.string :currency, null: false, default: "USD"
      t.integer :approval_status, null: false, default: 0
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    create_table :lessons do |t|
      t.references :course, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :video_url
      t.integer :sort_priority, null: false, default: 0

      t.timestamps
    end

    create_table :lesson_quizzes do |t|
      t.references :lesson, null: false, foreign_key: true, index: { unique: true }
      t.string :title, null: false

      t.timestamps
    end

    create_table :quiz_questions do |t|
      t.references :lesson_quiz, null: false, foreign_key: true
      t.text :question_text, null: false

      t.timestamps
    end

    create_table :quiz_options do |t|
      t.references :quiz_question, null: false, foreign_key: true
      t.string :option_text, null: false
      t.boolean :is_correct, null: false, default: false

      t.timestamps
    end
  end
end
