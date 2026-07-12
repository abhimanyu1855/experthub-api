# frozen_string_literal: true

puts "Clearing existing data..."
Review.destroy_all
Booking.destroy_all
Service.destroy_all
Category.destroy_all
WorkingTimeSlot.destroy_all
ExpertProfile.destroy_all
Membership.destroy_all
TenantSetupStep.destroy_all
GroupSession.destroy_all
Course.destroy_all
Lesson.destroy_all
User.destroy_all
Tenant.destroy_all

def seed_tenant(tenant_ident, tenant_name, suffix)
  puts "Seeding tenant: #{tenant_name} (#{tenant_ident})..."
  
  tenant = Tenant.create!(
    ident: tenant_ident,
    name: tenant_name,
    default_currency: "USD",
    seller_commission_pct: 10.0,
    buyer_commission_pct: 2.0,
    settings: {
      slogan: "Connect with world-class experts",
      primaryColor: "#6366f1",
      logoText: tenant_name.slice(0, 3).upcase
    }
  )

  # Create users for this tenant
  operator = User.create!(
    email: "operator#{suffix}@experthub.com",
    password: "password123",
    password_confirmation: "password123",
    given_name: "Alex",
    family_name: "Johnson",
    display_name: "Alex the Operator"
  )
  operator.skip_confirmation! if operator.respond_to?(:skip_confirmation!)

  expert_jordan = User.create!(
    email: "jordan#{suffix}@experthub.com",
    password: "password123",
    password_confirmation: "password123",
    given_name: "Jordan",
    family_name: "Rivera",
    display_name: "Jordan Rivera"
  )
  expert_jordan.skip_confirmation! if expert_jordan.respond_to?(:skip_confirmation!)

  expert_chen = User.create!(
    email: "chen#{suffix}@experthub.com",
    password: "password123",
    password_confirmation: "password123",
    given_name: "Chen",
    family_name: "Wei",
    display_name: "Dr. Chen Wei"
  )
  expert_chen.skip_confirmation! if expert_chen.respond_to?(:skip_confirmation!)

  client = User.create!(
    email: "client#{suffix}@experthub.com",
    password: "password123",
    password_confirmation: "password123",
    given_name: "Sarah",
    family_name: "Miller",
    display_name: "Sarah Miller"
  )
  client.skip_confirmation! if client.respond_to?(:skip_confirmation!)

  # Onboarding status checklist pre-seed
  %w[name brand payments domain landing experts].each_with_index do |step_id, idx|
    tenant.tenant_setup_steps.create!(
      step_id: step_id,
      completed: idx < 3, # Mark name, brand, payments as completed by default to show progress
      active: idx == 3
    )
  end

  # Memberships
  Membership.create!(user: operator, tenant: tenant, role: "operator", status: "active")
  Membership.create!(user: expert_jordan, tenant: tenant, role: "expert", status: "active")
  Membership.create!(user: expert_chen, tenant: tenant, role: "expert", status: "active")
  Membership.create!(user: client, tenant: tenant, role: "client", status: "active")

  # Categories
  tech = Category.create!(tenant: tenant, name: "Technology", category_type: "service")
  design = Category.create!(tenant: tenant, name: "Design", category_type: "service")
  biz = Category.create!(tenant: tenant, name: "Business Strategy", category_type: "service")
  marketing = Category.create!(tenant: tenant, name: "Marketing", category_type: "service")

  # Expert Profiles
  jordan_profile = ExpertProfile.create!(
    user: expert_jordan,
    tenant: tenant,
    title: "Product Strategy & Growth Expert",
    specialization: "Product Management, Business Strategy",
    bio: "10+ years building products at top-tier startups and enterprises. Former VP Product @ Stripe, MBA from Wharton. I help founders and PMs craft winning product strategies, prioritize roadmaps, and unlock sustainable growth.",
    approval_status: :approved,
    is_on_duty: true
  )

  chen_profile = ExpertProfile.create!(
    user: expert_chen,
    tenant: tenant,
    title: "Principal AI & Machine Learning Scientist",
    specialization: "Artificial Intelligence, Deep Learning, NLP",
    bio: "Ph.D. in Computer Science. Specialized in building large language models, generative AI platforms, and high-performance neural networks. Former AI lead at Google Brain.",
    approval_status: :approved,
    is_on_duty: true
  )

  # Services
  jordan_s1 = Service.create!(
    expert_profile: jordan_profile,
    tenant: tenant,
    category: biz,
    title: "1:1 Product Review & Strategy Consultation",
    description: "Get feedback on your product roadmap, feature prioritization, UX flow, and market positioning.",
    price_cents: 25000, # $250.00
    duration_minutes: 60,
    approval_status: :approved,
    is_active: true
  )

  jordan_s2 = Service.create!(
    expert_profile: jordan_profile,
    tenant: tenant,
    category: biz,
    title: "Pitch Deck Audit & Valuation Prep",
    description: "A thorough review of your investment slides and financial models to ensure readiness for seed/Series A rounds.",
    price_cents: 35000, # $350.00
    duration_minutes: 90,
    approval_status: :approved,
    is_active: true
  )

  chen_s1 = Service.create!(
    expert_profile: chen_profile,
    tenant: tenant,
    category: tech,
    title: "AI Architecture & Model Evaluation",
    description: "A deep dive session to evaluate your machine learning pipelines, transformer integrations, and training costs.",
    price_cents: 30000, # $300.00
    duration_minutes: 60,
    approval_status: :approved,
    is_active: true
  )

  # Availability time slots
  [jordan_profile, chen_profile].each do |profile|
    (1..5).each do |day|
      WorkingTimeSlot.create!(
        expert_profile: profile,
        week_day: day,
        from_time: "09:00",
        till_time: "17:00",
        is_active: true
      )
    end
  end

  # Bookings
  booking_jordan = Booking.create!(
    tenant: tenant,
    client: client,
    expert: expert_jordan,
    service: jordan_s1,
    price_cents: 25000,
    duration_minutes: 60,
    start_time: 2.days.ago,
    end_time: 2.days.ago + 1.hour,
    aasm_state: "confirmed"
  )

  booking_chen = Booking.create!(
    tenant: tenant,
    client: client,
    expert: expert_chen,
    service: chen_s1,
    price_cents: 30000,
    duration_minutes: 60,
    start_time: 1.day.ago,
    end_time: 1.day.ago + 1.hour,
    aasm_state: "confirmed"
  )

  # Video Rooms
  booking_jordan.create_video_room!(
    provider: "daily",
    url: "https://daily.co/mock-session-jordan-#{tenant_ident}",
    provider_room_id: "room_jordan_#{tenant_ident}"
  )

  booking_chen.create_video_room!(
    provider: "daily",
    url: "https://daily.co/mock-session-chen-#{tenant_ident}",
    provider_room_id: "room_chen_#{tenant_ident}"
  )

  # Reviews
  Review.create!(
    tenant: tenant,
    reviewable: booking_jordan,
    reviewer: client,
    reviewee: expert_jordan,
    rating: 5,
    content: "Jordan gave us incredibly valuable insights that helped us refine our Series A pitch. Highly recommend!"
  )

  Review.create!(
    tenant: tenant,
    reviewable: booking_chen,
    reviewer: client,
    reviewee: expert_chen,
    rating: 5,
    content: "Phenomenal architect! Helped us debug our transformer training runs and slashed our GPU budget by 40%."
  )

  # Courses
  course1 = Course.create!(
    tenant: tenant,
    expert_profile: jordan_profile,
    title: "Product Management Masterclass: Zero to PM Lead",
    description: "Learn how to build, scale, and manage world-class products. Covers roadmap design, backlog prioritization, and cross-functional leadership.",
    price_cents: 9900,
    approval_status: :approved,
    is_active: true
  )

  Lesson.create!(
    course: course1,
    title: "Introduction to Modern Product Management",
    description: "Understanding the role of a PM, key stakeholders, and alignment frameworks.",
    sort_priority: 1,
    video_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  )

  Lesson.create!(
    course: course1,
    title: "Finding Product-Market Fit",
    description: "User research methods, hypothesis testing, and landing page testing.",
    sort_priority: 2,
    video_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  )

  # Enroll client in course
  Enrollment.create!(
    tenant: tenant,
    course: course1,
    user: client,
    status: "active"
  )

  # Group Sessions
  GroupSession.create!(
    tenant: tenant,
    expert_profile: chen_profile,
    title: "AI Scaling Secrets: Distributed LLM Training & Inference",
    description: "Join this live cohort session to discuss pipeline parallelism, model parallelism, and DeepSpeed configurations.",
    price_cents: 4900,
    start_time: 3.days.from_now.change(hour: 15, min: 0),
    end_time: 3.days.from_now.change(hour: 16, min: 30),
    max_participants: 25,
    video_room_url: "https://daily.co/mock-session-chen-#{tenant_ident}"
  )
end

seed_tenant("acme", "Acme Expert Hub", "")
seed_tenant("acme2", "Acme Hub v2", "2")

puts "Database seeded successfully!"

if Rails.env.development? || ENV["SEED_DEMO"] == "1"
  load Rails.root.join("db/seeds/demo.rb")
end
