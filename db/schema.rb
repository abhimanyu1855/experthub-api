# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_13_142006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_triage_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "messages", default: [], null: false
    t.string "session_token", null: false
    t.string "status", default: "active", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["session_token"], name: "index_ai_triage_sessions_on_session_token", unique: true
    t.index ["tenant_id"], name: "index_ai_triage_sessions_on_tenant_id"
    t.index ["user_id"], name: "index_ai_triage_sessions_on_user_id"
  end

  create_table "blocked_dates", force: :cascade do |t|
    t.date "blocked_on", null: false
    t.datetime "created_at", null: false
    t.bigint "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id", "blocked_on"], name: "index_blocked_dates_on_service_id_and_blocked_on", unique: true
    t.index ["service_id"], name: "index_blocked_dates_on_service_id"
  end

  create_table "booking_packages", force: :cascade do |t|
    t.integer "booking_count", default: 5, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.text "description"
    t.bigint "expert_profile_id", null: false
    t.integer "price_cents", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["expert_profile_id"], name: "index_booking_packages_on_expert_profile_id"
    t.index ["tenant_id"], name: "index_booking_packages_on_tenant_id"
  end

  create_table "booking_transitions", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.datetime "created_at", null: false
    t.string "event"
    t.string "from_state"
    t.jsonb "metadata", default: {}
    t.integer "sort_key", null: false
    t.string "to_state", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id", "sort_key"], name: "index_booking_transitions_on_booking_id_and_sort_key", unique: true
    t.index ["booking_id"], name: "index_booking_transitions_on_booking_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.string "aasm_state", default: "pending", null: false
    t.datetime "auto_confirm_at"
    t.integer "buyer_fee_cents", default: 0, null: false
    t.string "calendar_event_id"
    t.bigint "cancellation_policy_id"
    t.bigint "client_id", null: false
    t.integer "commission_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.boolean "deleted", default: false
    t.integer "discount_cents", default: 0
    t.integer "duration_minutes"
    t.datetime "end_time", null: false
    t.bigint "expert_id", null: false
    t.integer "expert_payout_cents", default: 0, null: false
    t.jsonb "metadata", default: {}
    t.string "payment_status"
    t.integer "price_cents", null: false
    t.string "promo_code"
    t.bigint "service_id", null: false
    t.datetime "start_time", null: false
    t.string "stripe_payment_intent_id"
    t.string "stripe_transfer_id"
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.string "video_room_id"
    t.string "video_room_provider", default: "daily"
    t.string "video_room_url"
    t.index ["aasm_state"], name: "index_bookings_on_aasm_state"
    t.index ["cancellation_policy_id"], name: "index_bookings_on_cancellation_policy_id"
    t.index ["client_id"], name: "index_bookings_on_client_id"
    t.index ["expert_id", "start_time", "end_time"], name: "idx_bookings_expert_schedule"
    t.index ["expert_id"], name: "index_bookings_on_expert_id"
    t.index ["service_id"], name: "index_bookings_on_service_id"
    t.index ["stripe_payment_intent_id"], name: "index_bookings_on_stripe_payment_intent_id", unique: true, where: "(stripe_payment_intent_id IS NOT NULL)"
    t.index ["tenant_id", "aasm_state", "created_at"], name: "index_bookings_on_tenant_id_and_aasm_state_and_created_at"
    t.index ["tenant_id", "client_id"], name: "index_bookings_on_tenant_id_and_client_id"
    t.index ["tenant_id", "expert_id"], name: "index_bookings_on_tenant_id_and_expert_id"
    t.index ["tenant_id"], name: "index_bookings_on_tenant_id"
  end

  create_table "cancellation_policies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.integer "prior_hours", default: 24, null: false
    t.decimal "refund_percentage", precision: 5, scale: 2, default: "100.0", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_cancellation_policies_on_tenant_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "category_type", default: "service"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.string "slug"
    t.integer "sort_priority", default: 0
    t.bigint "tenant_id", null: false
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["tenant_id", "category_type", "sort_priority"], name: "idx_on_tenant_id_category_type_sort_priority_ff40fb5b85"
    t.index ["tenant_id", "slug"], name: "index_categories_on_tenant_id_and_slug", unique: true
    t.index ["tenant_id"], name: "index_categories_on_tenant_id"
  end

  create_table "certificates", force: :cascade do |t|
    t.string "certificate_code", null: false
    t.datetime "created_at", null: false
    t.bigint "enrollment_id", null: false
    t.datetime "issued_at", null: false
    t.datetime "updated_at", null: false
    t.index ["certificate_code"], name: "index_certificates_on_certificate_code", unique: true
    t.index ["enrollment_id"], name: "index_certificates_on_enrollment_id", unique: true
  end

  create_table "checkout_field_values", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "checkout_field_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "value", null: false
    t.index ["booking_id"], name: "index_checkout_field_values_on_booking_id"
    t.index ["checkout_field_id", "booking_id"], name: "idx_on_checkout_field_id_booking_id_22d0c65f80", unique: true
    t.index ["checkout_field_id"], name: "index_checkout_field_values_on_checkout_field_id"
  end

  create_table "checkout_fields", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "field_name", null: false
    t.string "field_type", null: false
    t.jsonb "options", default: [], null: false
    t.boolean "required", default: false, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_checkout_fields_on_tenant_id"
  end

  create_table "conversation_participations", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_read_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["conversation_id", "user_id"], name: "idx_on_conversation_id_user_id_f97afd54b3", unique: true
    t.index ["conversation_id"], name: "index_conversation_participations_on_conversation_id"
    t.index ["user_id"], name: "index_conversation_participations_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_conversations_on_tenant_id"
  end

  create_table "courses", force: :cascade do |t|
    t.integer "approval_status", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.text "description"
    t.bigint "expert_profile_id", null: false
    t.boolean "is_active", default: true, null: false
    t.integer "price_cents", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["expert_profile_id"], name: "index_courses_on_expert_profile_id"
    t.index ["tenant_id"], name: "index_courses_on_tenant_id"
  end

  create_table "enrollments", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.string "status", default: "active", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["course_id"], name: "index_enrollments_on_course_id"
    t.index ["tenant_id", "user_id"], name: "index_enrollments_on_tenant_id_and_user_id"
    t.index ["tenant_id"], name: "index_enrollments_on_tenant_id"
    t.index ["user_id", "course_id"], name: "index_enrollments_on_user_id_and_course_id", unique: true
    t.index ["user_id"], name: "index_enrollments_on_user_id"
  end

  create_table "expert_applications", force: :cascade do |t|
    t.jsonb "application_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "status", default: "pending", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["tenant_id"], name: "index_expert_applications_on_tenant_id"
    t.index ["user_id"], name: "index_expert_applications_on_user_id"
  end

  create_table "expert_embeddings", force: :cascade do |t|
    t.string "content_hash", null: false
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 1536, null: false
    t.bigint "expert_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expert_profile_id"], name: "index_expert_embeddings_on_expert_profile_id", unique: true
  end

  create_table "expert_profiles", force: :cascade do |t|
    t.integer "approval_status", default: 0
    t.decimal "average_rating", precision: 3, scale: 2, default: "0.0"
    t.text "bio"
    t.integer "bookings_count", default: 0
    t.datetime "created_at", null: false
    t.jsonb "credentials", default: []
    t.integer "default_slot_duration", default: 30
    t.string "intro_video_url"
    t.boolean "is_on_duty", default: true
    t.jsonb "press_links", default: []
    t.string "rejection_message"
    t.integer "reviews_count", default: 0
    t.text "specialization"
    t.string "stripe_account_id"
    t.bigint "tenant_id", null: false
    t.integer "timezone_offset", default: 0
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["tenant_id", "approval_status"], name: "index_expert_profiles_on_tenant_id_and_approval_status"
    t.index ["tenant_id"], name: "index_expert_profiles_on_tenant_id"
    t.index ["user_id", "tenant_id"], name: "index_expert_profiles_on_user_id_and_tenant_id", unique: true
  end

  create_table "group_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.text "description"
    t.datetime "end_time", null: false
    t.bigint "expert_profile_id", null: false
    t.integer "max_participants", default: 10, null: false
    t.integer "price_cents", default: 0, null: false
    t.datetime "start_time", null: false
    t.bigint "tenant_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "video_room_url"
    t.index ["expert_profile_id"], name: "index_group_sessions_on_expert_profile_id"
    t.index ["tenant_id", "start_time"], name: "index_group_sessions_on_tenant_id_and_start_time"
    t.index ["tenant_id"], name: "index_group_sessions_on_tenant_id"
  end

  create_table "lesson_progresses", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "enrollment_id", null: false
    t.bigint "lesson_id", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_id", "lesson_id"], name: "index_lesson_progresses_on_enrollment_id_and_lesson_id", unique: true
    t.index ["enrollment_id"], name: "index_lesson_progresses_on_enrollment_id"
    t.index ["lesson_id"], name: "index_lesson_progresses_on_lesson_id"
  end

  create_table "lesson_quizzes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "lesson_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id"], name: "index_lesson_quizzes_on_lesson_id", unique: true
  end

  create_table "lessons", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "sort_priority", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "video_url"
    t.index ["course_id"], name: "index_lessons_on_course_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["tenant_id", "role"], name: "index_memberships_on_tenant_id_and_role"
    t.index ["tenant_id"], name: "index_memberships_on_tenant_id"
    t.index ["user_id", "tenant_id"], name: "index_memberships_on_user_id_and_tenant_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "content", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.bigint "sender_id", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.string "notification_type", null: false
    t.datetime "read_at"
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["tenant_id", "user_id", "created_at"], name: "index_notifications_on_tenant_user_created"
    t.index ["tenant_id"], name: "index_notifications_on_tenant_id"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "package_purchases", force: :cascade do |t|
    t.bigint "booking_package_id", null: false
    t.datetime "created_at", null: false
    t.integer "remaining_bookings", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["booking_package_id"], name: "index_package_purchases_on_booking_package_id"
    t.index ["tenant_id"], name: "index_package_purchases_on_tenant_id"
    t.index ["user_id"], name: "index_package_purchases_on_user_id"
  end

  create_table "pages", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.boolean "is_published", default: true, null: false
    t.string "slug", null: false
    t.bigint "tenant_id", null: false
    t.string "title", null: false
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "slug"], name: "index_pages_on_tenant_id_and_slug", unique: true
    t.index ["tenant_id"], name: "index_pages_on_tenant_id"
  end

  create_table "payment_configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "encrypted_credentials"
    t.string "gateway", null: false
    t.boolean "is_active", default: true
    t.string "publishable_key"
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "gateway"], name: "index_payment_configs_on_tenant_id_and_gateway", unique: true
    t.index ["tenant_id"], name: "index_payment_configs_on_tenant_id"
  end

  create_table "payment_records", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.bigint "booking_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "gateway", default: "stripe", null: false
    t.jsonb "provider_data", default: {}
    t.string "provider_id"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_payment_records_on_booking_id"
    t.index ["gateway", "provider_id"], name: "index_payment_records_on_gateway_and_provider_id"
  end

  create_table "payout_accounts", force: :cascade do |t|
    t.string "account_identifier", null: false
    t.datetime "created_at", null: false
    t.bigint "expert_profile_id", null: false
    t.string "gateway", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["expert_profile_id", "gateway"], name: "index_payout_accounts_on_expert_profile_id_and_gateway", unique: true
    t.index ["expert_profile_id"], name: "index_payout_accounts_on_expert_profile_id"
  end

  create_table "promo_codes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "discount_type", null: false
    t.decimal "discount_value", precision: 10, scale: 2, null: false
    t.datetime "expires_at"
    t.integer "max_redemptions"
    t.integer "redemptions_count", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_promo_codes_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_promo_codes_on_tenant_id"
  end

  create_table "promo_redemptions", force: :cascade do |t|
    t.bigint "booking_id"
    t.datetime "created_at", null: false
    t.bigint "promo_code_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["booking_id"], name: "index_promo_redemptions_on_booking_id"
    t.index ["promo_code_id"], name: "index_promo_redemptions_on_promo_code_id"
    t.index ["user_id"], name: "index_promo_redemptions_on_user_id"
  end

  create_table "quiz_options", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_correct", default: false, null: false
    t.string "option_text", null: false
    t.bigint "quiz_question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_question_id"], name: "index_quiz_options_on_quiz_question_id"
  end

  create_table "quiz_questions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "lesson_quiz_id", null: false
    t.text "question_text", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_quiz_id"], name: "index_quiz_questions_on_lesson_quiz_id"
  end

  create_table "referral_credits", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.bigint "referred_user_id"
    t.string "status", default: "active", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["referred_user_id"], name: "index_referral_credits_on_referred_user_id"
    t.index ["tenant_id"], name: "index_referral_credits_on_tenant_id"
    t.index ["user_id"], name: "index_referral_credits_on_user_id"
  end

  create_table "reschedule_requests", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "new_end_time", null: false
    t.datetime "new_start_time", null: false
    t.datetime "old_end_time", null: false
    t.datetime "old_start_time", null: false
    t.text "reason"
    t.bigint "requested_by_id", null: false
    t.string "status", default: "pending", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id", "status"], name: "index_reschedule_requests_on_booking_id_and_status"
    t.index ["booking_id"], name: "index_reschedule_requests_on_booking_id"
    t.index ["requested_by_id"], name: "index_reschedule_requests_on_requested_by_id"
    t.index ["tenant_id"], name: "index_reschedule_requests_on_tenant_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "rating", null: false
    t.bigint "reviewable_id", null: false
    t.string "reviewable_type", null: false
    t.bigint "reviewee_id"
    t.bigint "reviewer_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["reviewable_type", "reviewable_id"], name: "index_reviews_on_reviewable"
    t.index ["reviewee_id"], name: "index_reviews_on_reviewee_id"
    t.index ["reviewer_id"], name: "index_reviews_on_reviewer_id"
    t.index ["tenant_id", "reviewable_type", "reviewable_id"], name: "idx_on_tenant_id_reviewable_type_reviewable_id_49621c568b"
    t.index ["tenant_id"], name: "index_reviews_on_tenant_id"
  end

  create_table "services", force: :cascade do |t|
    t.boolean "allow_multiple_bookings", default: false
    t.integer "approval_status", default: 0
    t.integer "booking_buffer_minutes", default: 0
    t.bigint "cancellation_policy_id"
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.text "description"
    t.integer "duration_minutes", default: 30
    t.bigint "expert_profile_id", null: false
    t.boolean "is_active", default: true
    t.boolean "is_featured", default: false
    t.integer "max_concurrent_bookings", default: 1
    t.integer "price_cents", default: 0, null: false
    t.string "rejection_message"
    t.integer "room_type", default: 3
    t.integer "slot_interval_minutes", default: 30
    t.string "slug"
    t.integer "sort_position", default: 0
    t.bigint "tenant_id", null: false
    t.integer "times_viewed", default: 0
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["cancellation_policy_id"], name: "index_services_on_cancellation_policy_id"
    t.index ["category_id"], name: "index_services_on_category_id"
    t.index ["expert_profile_id"], name: "index_services_on_expert_profile_id"
    t.index ["tenant_id", "approval_status", "is_active"], name: "index_services_on_tenant_id_and_approval_status_and_is_active"
    t.index ["tenant_id", "slug"], name: "index_services_on_tenant_id_and_slug", unique: true
    t.index ["tenant_id"], name: "index_services_on_tenant_id"
  end

  create_table "session_attendances", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "group_session_id", null: false
    t.string "status", default: "registered", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["group_session_id", "user_id"], name: "index_session_attendances_on_group_session_id_and_user_id", unique: true
    t.index ["group_session_id"], name: "index_session_attendances_on_group_session_id"
    t.index ["user_id"], name: "index_session_attendances_on_user_id"
  end

  create_table "session_summaries", force: :cascade do |t|
    t.jsonb "action_items", default: [], null: false
    t.bigint "booking_id", null: false
    t.datetime "created_at", null: false
    t.text "summary", null: false
    t.text "transcript"
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_session_summaries_on_booking_id", unique: true
  end

  create_table "subscription_plans", force: :cascade do |t|
    t.string "billing_interval", default: "monthly", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.bigint "expert_profile_id"
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.string "target_role", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expert_profile_id"], name: "index_subscription_plans_on_expert_profile_id"
    t.index ["tenant_id"], name: "index_subscription_plans_on_tenant_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.string "status", default: "active", null: false
    t.string "stripe_subscription_id"
    t.bigint "subscription_plan_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", where: "(stripe_subscription_id IS NOT NULL)"
    t.index ["subscription_plan_id"], name: "index_subscriptions_on_subscription_plan_id"
    t.index ["tenant_id"], name: "index_subscriptions_on_tenant_id"
    t.index ["user_id", "subscription_plan_id"], name: "index_subscriptions_on_user_id_and_subscription_plan_id"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "tenant_setup_steps", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.string "step_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "step_id"], name: "index_tenant_setup_steps_on_tenant_id_and_step_id", unique: true
    t.index ["tenant_id"], name: "index_tenant_setup_steps_on_tenant_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.decimal "buyer_commission_pct", precision: 5, scale: 2, default: "0.0"
    t.string "cover_photo_url"
    t.datetime "created_at", null: false
    t.string "custom_domain"
    t.string "custom_domain_status", default: "pending"
    t.string "default_currency", default: "USD"
    t.text "description"
    t.string "dns_txt_record"
    t.string "domain"
    t.jsonb "feature_flags", default: {}
    t.string "ident", null: false
    t.string "locale", default: "en"
    t.string "locked_vertical"
    t.string "logo_url"
    t.integer "max_experts"
    t.integer "minimum_commission_cents", default: 0
    t.string "name", null: false
    t.string "plan", default: "trial"
    t.decimal "seller_commission_pct", precision: 5, scale: 2, default: "15.0"
    t.jsonb "settings", default: {}
    t.boolean "single_expert", default: false
    t.string "slogan"
    t.string "stripe_subscription_id"
    t.jsonb "supported_locales", default: ["en"], null: false
    t.jsonb "theme", default: {}
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["custom_domain"], name: "index_tenants_on_custom_domain", unique: true, where: "(custom_domain IS NOT NULL)"
    t.index ["domain"], name: "index_tenants_on_domain", unique: true, where: "(domain IS NOT NULL)"
    t.index ["ident"], name: "index_tenants_on_ident", unique: true
    t.index ["stripe_subscription_id"], name: "index_tenants_on_stripe_subscription_id", unique: true, where: "(stripe_subscription_id IS NOT NULL)"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.text "description"
    t.string "display_name"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "family_name"
    t.string "given_name", null: false
    t.string "jti", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.string "phone_number"
    t.string "referral_code"
    t.string "referred_by_code"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["referral_code"], name: "index_users_on_referral_code", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "video_rooms", force: :cascade do |t|
    t.bigint "booking_id"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.string "provider", default: "daily", null: false
    t.string "provider_room_id"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["booking_id"], name: "index_video_rooms_on_booking_id"
  end

  create_table "working_time_slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "expert_profile_id", null: false
    t.string "from_time", null: false
    t.boolean "is_active", default: true
    t.string "till_time", null: false
    t.datetime "updated_at", null: false
    t.integer "week_day", null: false
    t.index ["expert_profile_id", "week_day"], name: "index_working_time_slots_on_expert_profile_id_and_week_day"
    t.index ["expert_profile_id"], name: "index_working_time_slots_on_expert_profile_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_triage_sessions", "tenants"
  add_foreign_key "ai_triage_sessions", "users"
  add_foreign_key "blocked_dates", "services"
  add_foreign_key "booking_packages", "expert_profiles"
  add_foreign_key "booking_packages", "tenants"
  add_foreign_key "booking_transitions", "bookings"
  add_foreign_key "bookings", "cancellation_policies"
  add_foreign_key "bookings", "services"
  add_foreign_key "bookings", "tenants"
  add_foreign_key "bookings", "users", column: "client_id"
  add_foreign_key "bookings", "users", column: "expert_id"
  add_foreign_key "cancellation_policies", "tenants"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "categories", "tenants"
  add_foreign_key "certificates", "enrollments"
  add_foreign_key "checkout_field_values", "bookings"
  add_foreign_key "checkout_field_values", "checkout_fields"
  add_foreign_key "checkout_fields", "tenants"
  add_foreign_key "conversation_participations", "conversations"
  add_foreign_key "conversation_participations", "users"
  add_foreign_key "conversations", "tenants"
  add_foreign_key "courses", "expert_profiles"
  add_foreign_key "courses", "tenants"
  add_foreign_key "enrollments", "courses"
  add_foreign_key "enrollments", "tenants"
  add_foreign_key "enrollments", "users"
  add_foreign_key "expert_applications", "tenants"
  add_foreign_key "expert_applications", "users"
  add_foreign_key "expert_embeddings", "expert_profiles"
  add_foreign_key "expert_profiles", "tenants"
  add_foreign_key "expert_profiles", "users"
  add_foreign_key "group_sessions", "expert_profiles"
  add_foreign_key "group_sessions", "tenants"
  add_foreign_key "lesson_progresses", "enrollments"
  add_foreign_key "lesson_progresses", "lessons"
  add_foreign_key "lesson_quizzes", "lessons"
  add_foreign_key "lessons", "courses"
  add_foreign_key "memberships", "tenants"
  add_foreign_key "memberships", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "notifications", "tenants"
  add_foreign_key "notifications", "users"
  add_foreign_key "package_purchases", "booking_packages"
  add_foreign_key "package_purchases", "tenants"
  add_foreign_key "package_purchases", "users"
  add_foreign_key "pages", "tenants"
  add_foreign_key "payment_configs", "tenants"
  add_foreign_key "payment_records", "bookings"
  add_foreign_key "payout_accounts", "expert_profiles"
  add_foreign_key "promo_codes", "tenants"
  add_foreign_key "promo_redemptions", "bookings"
  add_foreign_key "promo_redemptions", "promo_codes"
  add_foreign_key "promo_redemptions", "users"
  add_foreign_key "quiz_options", "quiz_questions"
  add_foreign_key "quiz_questions", "lesson_quizzes"
  add_foreign_key "referral_credits", "tenants"
  add_foreign_key "referral_credits", "users"
  add_foreign_key "referral_credits", "users", column: "referred_user_id"
  add_foreign_key "reschedule_requests", "bookings"
  add_foreign_key "reschedule_requests", "tenants"
  add_foreign_key "reschedule_requests", "users", column: "requested_by_id"
  add_foreign_key "reviews", "tenants"
  add_foreign_key "reviews", "users", column: "reviewee_id"
  add_foreign_key "reviews", "users", column: "reviewer_id"
  add_foreign_key "services", "cancellation_policies"
  add_foreign_key "services", "categories"
  add_foreign_key "services", "expert_profiles"
  add_foreign_key "services", "tenants"
  add_foreign_key "session_attendances", "group_sessions"
  add_foreign_key "session_attendances", "users"
  add_foreign_key "session_summaries", "bookings"
  add_foreign_key "subscription_plans", "expert_profiles"
  add_foreign_key "subscription_plans", "tenants"
  add_foreign_key "subscriptions", "subscription_plans"
  add_foreign_key "subscriptions", "tenants"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "tenant_setup_steps", "tenants"
  add_foreign_key "video_rooms", "bookings"
  add_foreign_key "working_time_slots", "expert_profiles"
end
