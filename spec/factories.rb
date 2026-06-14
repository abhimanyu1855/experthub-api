# frozen_string_literal: true

FactoryBot.define do
  factory :tenant do
    sequence(:ident) { |n| "tenant-#{n}" }
    name { "ExpertHub Tenant" }
    default_currency { "USD" }
    seller_commission_pct { 15.0 }
    buyer_commission_pct { 0.0 }
    minimum_commission_cents { 0 }
    settings { { "require_expert_approval" => false } }
  end

  factory :user do
    sequence(:email) { |n| "user-#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    given_name { "John" }
    family_name { "Doe" }
    jti { SecureRandom.uuid }

    trait :confirmed do
      after(:build) { |user| user.skip_confirmation! }
    end
  end

  factory :membership do
    user
    tenant
    role { :client }
    status { :active }
  end

  factory :expert_profile do
    user
    tenant
    specialization { "Ruby on Rails Development" }
    bio { "Experienced full stack software engineer." }
    title { "Senior Engineer" }
    timezone_offset { 0 }
    default_slot_duration { 30 }
    is_on_duty { true }
    approval_status { :approved }
  end

  factory :category do
    tenant
    name { "Software Engineering" }
    sequence(:slug) { |n| "software-engineering-#{n}" }
    category_type { "service" }
  end

  factory :service do
    expert_profile
    tenant
    category
    title { "Rails Architecture Consultation" }
    price_cents { 10000 } # $100
    currency { "USD" }
    duration_minutes { 60 }
    slot_interval_minutes { 60 }
    approval_status { :approved }
    is_active { true }
  end

  factory :booking do
    service
    tenant
    client { association :user, :confirmed }
    expert { service.expert_profile.user }
    start_time { Time.current + 1.hour }
    end_time { Time.current + 2.hours }
    price_cents { service.price_cents }
    currency { "USD" }
  end

  factory :payment_config do
    tenant
    gateway { "stripe" }
    publishable_key { "pk_test_123" }
    encrypted_credentials { "sk_test_123" }
    is_active { true }
  end

  factory :working_time_slot do
    expert_profile
    week_day { 1 }
    from_time { "09:00" }
    till_time { "17:00" }
    is_active { true }
  end

  factory :blocked_date do
    service
    blocked_on { Date.current }
  end

  factory :payment_record do
    booking
    gateway { "stripe" }
    amount_cents { 1000 }
    currency { "USD" }
    status { "succeeded" }
    provider_id { "pi_test_123" }
  end

  factory :payout_account do
    expert_profile
    gateway { "stripe" }
    account_identifier { "acct_123" }
    status { "active" }
  end

  factory :review do
    tenant
    association :reviewer, factory: :user
    association :reviewee, factory: :user
    association :reviewable, factory: :service
    rating { 5 }
    content { "Very detailed and helpful session!" }
  end

  factory :reschedule_request do
    tenant
    booking
    association :requested_by, factory: :user
    old_start_time { booking.start_time }
    old_end_time { booking.end_time }
    new_start_time { booking.start_time + 1.day }
    new_end_time { booking.end_time + 1.day }
    status { "pending" }
    reason { "Unexpected conflicts came up." }
    expires_at { booking.start_time }
  end

  factory :cancellation_policy do
    tenant
    name { "Standard 24h Policy" }
    refund_percentage { 100.00 }
    prior_hours { 24 }
    is_active { true }
  end

  factory :conversation do
    tenant
  end

  factory :conversation_participation do
    conversation
    user
  end

  factory :message do
    conversation
    association :sender, factory: :user
    content { "Hello there!" }
  end

  factory :notification do
    tenant
    user
    notification_type { "test_notification" }
    data { { "msg" => "This is a test notification." } }
  end

  factory :expert_embedding do
    expert_profile
    embedding { Array.new(1536) { rand - 0.5 } }
    content_hash { "hash_value" }
  end

  factory :ai_triage_session do
    tenant
    user
    sequence(:session_token) { |n| "token_#{n}" }
    messages { [{ "role" => "assistant", "content" => "How can I help you?" }] }
    status { "active" }
  end

  factory :session_summary do
    booking
    summary { "The session covered architecture topics and API designs." }
    action_items { [{ "description" => "Send documentation", "assignee" => "expert" }] }
  end

  factory :course do
    tenant
    expert_profile
    title { "Introduction to Ruby on Rails 8" }
    description { "Learn the fundamentals of Rails 8." }
    price_cents { 4900 }
    currency { "USD" }
    approval_status { :approved }
    is_active { true }
  end

  factory :lesson do
    course
    title { "Getting Started" }
    description { "This lesson covers initial installation." }
    video_url { "https://example.com/video.mp4" }
    sequence(:sort_priority) { |n| n }
  end

  factory :lesson_quiz do
    lesson
    title { "Lesson Quiz" }
  end

  factory :quiz_question do
    association :quiz, factory: :lesson_quiz
    question_text { "What is the command to create a new rails app?" }
  end

  factory :quiz_option do
    association :question, factory: :quiz_question
    option_text { "rails new" }
    is_correct { true }
  end

  factory :enrollment do
    tenant
    course
    user
    status { "active" }
  end

  factory :lesson_progress do
    enrollment
    lesson
    completed_at { Time.current }
  end

  factory :certificate do
    enrollment
    sequence(:certificate_code) { |n| "CERT-#{SecureRandom.hex(4).upcase}-#{n}" }
    issued_at { Time.current }
  end

  factory :group_session do
    tenant
    expert_profile
    title { "Live Rails 8 Q&A" }
    description { "Interactive group discussion." }
    start_time { Time.current + 1.hour }
    end_time { Time.current + 2.hours }
    price_cents { 2000 }
    currency { "USD" }
    max_participants { 10 }
    video_room_url { "https://daily.co/xyz" }
  end

  factory :session_attendance do
    group_session
    user
    status { "registered" }
  end

  factory :booking_package do
    tenant
    expert_profile
    title { "5-Hour Architecture Bundle" }
    description { "Package of 5 hours of consultation." }
    price_cents { 40000 }
    currency { "USD" }
    booking_count { 5 }
  end

  factory :package_purchase do
    tenant
    booking_package
    user
    remaining_bookings { booking_package.booking_count }
  end

  factory :subscription_plan do
    tenant
    name { "Premium Expert Plan" }
    price_cents { 9900 }
    currency { "USD" }
    billing_interval { "monthly" }
    target_role { "expert" }
  end

  factory :subscription do
    tenant
    user
    subscription_plan
    status { "active" }
    current_period_end { Time.current + 1.month }
    sequence(:stripe_subscription_id) { |n| "sub_#{n}" }
  end

  factory :promo_code do
    tenant
    sequence(:code) { |n| "DISCOUNT#{n}" }
    discount_type { "percent" }
    discount_value { 10.0 }
    expires_at { Time.current + 1.month }
    max_redemptions { 100 }
    redemptions_count { 0 }
  end

  factory :promo_redemption do
    promo_code
    booking
    user
  end

  factory :checkout_field do
    tenant
    field_name { "Company Name" }
    field_type { "text" }
    required { false }
    options { [] }
  end

  factory :checkout_field_value do
    checkout_field
    booking
    value { "Google" }
  end

  factory :page do
    tenant
    sequence(:slug) { |n| "about-us-#{n}" }
    title { "About Us" }
    content { "We are ExpertHub." }
    is_published { true }
  end

  factory :referral_credit do
    tenant
    user
    amount_cents { 1000 }
    currency { "USD" }
    status { "active" }
  end
end


