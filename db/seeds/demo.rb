# frozen_string_literal: true

# db/seeds/demo.rb
#
# Demo marketplace seed for "SOS My Doctor" (ident: sosmydoctor).
# Sets up a fully working demo tenant so the entire booking + payment flow
# can be tested end-to-end.
#
# Stripe keys below are TEST keys only — in production every tenant enters
# their own keys via the admin panel and they are stored encrypted at rest.
# NEVER commit real/live Stripe keys to version control.
#
# Safe to run multiple times (idempotent via find_or_create_by patterns).

puts "\n=== Seeding SOS My Doctor demo marketplace ==="

# ---------------------------------------------------------------------------
# Tenant
# ---------------------------------------------------------------------------
tenant = Tenant.find_or_initialize_by(ident: "sosmydoctor")
tenant.assign_attributes(
  name: "SOS My Doctor",
  default_currency: "INR",
  seller_commission_pct: 10.0,
  buyer_commission_pct: 2.0,
  plan: "pro",
  locale: "en",
  settings: {
    "slogan"                   => "Expert medical consultations, on demand",
    "primaryColor"             => "#0ea5e9",
    "logoText"                 => "SOS",
    "booking_buffer_minutes"   => 15,
    "auto_confirm_bookings"    => false,
    "require_expert_approval"  => true,
    "send_booking_emails"      => true,
    "webhooks_enabled"         => false,
    "enable_courses"           => false,
    "enable_sessions"          => false,
    "enable_packages"          => false,
    "enable_subscriptions"     => false
  },
  feature_flags: {
    "ai_matching"        => true,
    "triage_chatbot"     => true,
    "session_summaries"  => true
  }
)
tenant.save!
puts "  Tenant: #{tenant.name} (#{tenant.ident}) — plan: #{tenant.plan}"

# ---------------------------------------------------------------------------
# Onboarding / setup steps (all marked completed so the admin UI is clean)
# ---------------------------------------------------------------------------
%w[name brand payments domain landing experts].each_with_index do |step_id, idx|
  tenant.tenant_setup_steps.find_or_create_by!(step_id: step_id) do |s|
    s.completed = true
    s.active    = false
  end
end
puts "  Setup steps: created/verified"

# ---------------------------------------------------------------------------
# Helper: create-or-update a User
# ---------------------------------------------------------------------------
def find_or_create_demo_user(email:, password:, given_name:, family_name:, display_name:)
  user = User.find_or_initialize_by(email: email)
  if user.new_record?
    user.assign_attributes(
      password:              password,
      password_confirmation: password,
      given_name:            given_name,
      family_name:           family_name,
      display_name:          display_name
    )
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
    user.save!
  end
  user
end

# ---------------------------------------------------------------------------
# Operator (marketplace admin)
# ---------------------------------------------------------------------------
admin = find_or_create_demo_user(
  email:        "admin@sosmydoctor.com",
  password:     "Demo1234!",
  given_name:   "Admin",
  family_name:  "SOS",
  display_name: "SOS Admin"
)
Membership.find_or_create_by!(user: admin, tenant: tenant) do |m|
  m.role   = :operator
  m.status = :active
end
puts "  Operator: #{admin.email}"

# ---------------------------------------------------------------------------
# Stripe PaymentConfig
# NOTE: These are Stripe TEST keys. In production each tenant supplies their
# own keys through the admin panel — they are stored encrypted at rest.
# ---------------------------------------------------------------------------
payment_config = PaymentConfig.find_or_initialize_by(tenant: tenant, gateway: "stripe")
payment_config.assign_attributes(
  publishable_key:        "pk_test_51RKS11Gd3c7RGaNTOZ7aouVEV6CeBRp98TJQAUI42s7F81XhMcF45pPxhGZKIhuoQ6CsNx50FoIkkqAlGRPUHhWE00CJYfT8nd",
  encrypted_credentials:  { "secret_key" => "sk_test_51RKS11Gd3c7RGaNT2k5RqPyxzTuSuP3Lo3ihARaM8RgC5yhcfEDBAeKMg5LZmgoQbDCPGNcU3TxRrewaLQQiYVjX005mbL9qYd" }.to_json,
  is_active:              true
)
payment_config.save!
puts "  PaymentConfig: Stripe — active"

# ---------------------------------------------------------------------------
# Categories
# ---------------------------------------------------------------------------
category_data = [
  { name: "General Consultation",    sort_priority: 1 },
  { name: "Specialist Consultation", sort_priority: 2 },
  { name: "Mental Health",           sort_priority: 3 },
  { name: "Nutrition & Wellness",    sort_priority: 4 }
]

categories = category_data.each_with_object({}) do |cat, h|
  slug = cat[:name].parameterize
  record = Category.find_or_create_by!(tenant: tenant, slug: slug) do |c|
    c.name          = cat[:name]
    c.category_type = "service"
    c.sort_priority = cat[:sort_priority]
  end
  h[cat[:name]] = record
end
puts "  Categories: #{categories.keys.join(', ')}"

# ---------------------------------------------------------------------------
# Expert 1 — Dr. Priya Sharma (GP)
# ---------------------------------------------------------------------------
priya = find_or_create_demo_user(
  email:        "dr.priya@sosmydoctor.com",
  password:     "Demo1234!",
  given_name:   "Priya",
  family_name:  "Sharma",
  display_name: "Dr. Priya Sharma"
)
Membership.find_or_create_by!(user: priya, tenant: tenant) do |m|
  m.role   = :expert
  m.status = :active
end

priya_profile = ExpertProfile.find_or_create_by!(user: priya, tenant: tenant) do |ep|
  ep.title           = "Dr."
  ep.specialization  = "General Practitioner with 10 years of experience in family medicine"
  ep.bio             = "Compassionate doctor specializing in preventive care and chronic disease management"
  ep.approval_status = :approved
  ep.is_on_duty      = true
end

priya_s1 = Service.find_or_create_by!(expert_profile: priya_profile, tenant: tenant, title: "General Consultation") do |s|
  s.category         = categories["General Consultation"]
  s.description      = "Comprehensive general health consultation covering diagnosis, treatment planning, and health advice."
  s.price_cents      = 50000
  s.currency         = "INR"
  s.duration_minutes = 30
  s.approval_status  = :approved
  s.is_active        = true
end

priya_s2 = Service.find_or_create_by!(expert_profile: priya_profile, tenant: tenant, title: "Follow-up Visit") do |s|
  s.category         = categories["General Consultation"]
  s.description      = "Short follow-up session to review progress, adjust medications, and answer questions."
  s.price_cents      = 25000
  s.currency         = "INR"
  s.duration_minutes = 15
  s.approval_status  = :approved
  s.is_active        = true
end

(1..5).each do |day|
  WorkingTimeSlot.find_or_create_by!(expert_profile: priya_profile, week_day: day) do |w|
    w.from_time = "09:00"
    w.till_time = "17:00"
    w.is_active = true
  end
end
puts "  Expert 1: #{priya.display_name} (#{priya_s1.title}, #{priya_s2.title})"

# ---------------------------------------------------------------------------
# Expert 2 — Dr. Rahul Menon (Cardiologist)
# ---------------------------------------------------------------------------
rahul = find_or_create_demo_user(
  email:        "dr.rahul@sosmydoctor.com",
  password:     "Demo1234!",
  given_name:   "Rahul",
  family_name:  "Menon",
  display_name: "Dr. Rahul Menon"
)
Membership.find_or_create_by!(user: rahul, tenant: tenant) do |m|
  m.role   = :expert
  m.status = :active
end

rahul_profile = ExpertProfile.find_or_create_by!(user: rahul, tenant: tenant) do |ep|
  ep.title           = "Dr."
  ep.specialization  = "Cardiologist with expertise in preventive cardiology"
  ep.bio             = "Senior cardiologist with 15 years of clinical experience. Specializes in non-invasive cardiology, ECG interpretation, and lifestyle-based cardiovascular risk reduction."
  ep.approval_status = :approved
  ep.is_on_duty      = true
end

rahul_s1 = Service.find_or_create_by!(expert_profile: rahul_profile, tenant: tenant, title: "Cardiology Consultation") do |s|
  s.category         = categories["Specialist Consultation"]
  s.description      = "Detailed cardiovascular assessment including risk stratification, ECG review, and lifestyle counselling."
  s.price_cents      = 150000
  s.currency         = "INR"
  s.duration_minutes = 45
  s.approval_status  = :approved
  s.is_active        = true
end

(1..5).each do |day|
  WorkingTimeSlot.find_or_create_by!(expert_profile: rahul_profile, week_day: day) do |w|
    w.from_time = "10:00"
    w.till_time = "18:00"
    w.is_active = true
  end
end
puts "  Expert 2: #{rahul.display_name} (#{rahul_s1.title})"

# ---------------------------------------------------------------------------
# Expert 3 — Dr. Ananya Patel (Clinical Psychologist)
# ---------------------------------------------------------------------------
ananya = find_or_create_demo_user(
  email:        "dr.ananya@sosmydoctor.com",
  password:     "Demo1234!",
  given_name:   "Ananya",
  family_name:  "Patel",
  display_name: "Dr. Ananya Patel"
)
Membership.find_or_create_by!(user: ananya, tenant: tenant) do |m|
  m.role   = :expert
  m.status = :active
end

ananya_profile = ExpertProfile.find_or_create_by!(user: ananya, tenant: tenant) do |ep|
  ep.title           = "Dr."
  ep.specialization  = "Clinical Psychologist specializing in anxiety and depression"
  ep.bio             = "Certified clinical psychologist with 8 years of experience in cognitive-behavioural therapy (CBT), mindfulness-based interventions, and trauma-informed care."
  ep.approval_status = :approved
  ep.is_on_duty      = true
end

ananya_s1 = Service.find_or_create_by!(expert_profile: ananya_profile, tenant: tenant, title: "Mental Health Session") do |s|
  s.category         = categories["Mental Health"]
  s.description      = "Confidential one-on-one therapy session addressing anxiety, depression, stress, or other mental health concerns."
  s.price_cents      = 120000
  s.currency         = "INR"
  s.duration_minutes = 60
  s.approval_status  = :approved
  s.is_active        = true
end

(1..5).each do |day|
  WorkingTimeSlot.find_or_create_by!(expert_profile: ananya_profile, week_day: day) do |w|
    w.from_time = "09:00"
    w.till_time = "17:00"
    w.is_active = true
  end
end
puts "  Expert 3: #{ananya.display_name} (#{ananya_s1.title})"

# ---------------------------------------------------------------------------
# Client — Raj Kumar
# ---------------------------------------------------------------------------
raj = find_or_create_demo_user(
  email:        "patient@example.com",
  password:     "Demo1234!",
  given_name:   "Raj",
  family_name:  "Kumar",
  display_name: "Raj Kumar"
)
Membership.find_or_create_by!(user: raj, tenant: tenant) do |m|
  m.role   = :client
  m.status = :active
end
puts "  Client: #{raj.display_name} (#{raj.email})"

# ---------------------------------------------------------------------------
# Historical bookings + reviews (only create if none exist for this client)
# ---------------------------------------------------------------------------
if Booking.where(tenant: tenant, client: raj).none?
  # Historical bookings are created in the initial :pending state, then
  # update_column is used to bypass AASM callbacks/validations and set
  # the final :confirmed state directly (there is no :completed state).
  booking_priya = Booking.create!(
    tenant:           tenant,
    client:           raj,
    expert:           priya,
    service:          priya_s1,
    price_cents:      50000,
    currency:         "INR",
    duration_minutes: 30,
    start_time:       3.days.ago.change(hour: 10, min: 0),
    end_time:         3.days.ago.change(hour: 10, min: 30)
  )
  booking_priya.update_column(:aasm_state, "confirmed")
  booking_priya.update_column(:payment_status, "paid")

  booking_rahul = Booking.create!(
    tenant:           tenant,
    client:           raj,
    expert:           rahul,
    service:          rahul_s1,
    price_cents:      150000,
    currency:         "INR",
    duration_minutes: 45,
    start_time:       5.days.ago.change(hour: 11, min: 0),
    end_time:         5.days.ago.change(hour: 11, min: 45)
  )
  booking_rahul.update_column(:aasm_state, "confirmed")
  booking_rahul.update_column(:payment_status, "paid")

  booking_ananya = Booking.create!(
    tenant:           tenant,
    client:           raj,
    expert:           ananya,
    service:          ananya_s1,
    price_cents:      120000,
    currency:         "INR",
    duration_minutes: 60,
    start_time:       7.days.ago.change(hour: 14, min: 0),
    end_time:         7.days.ago.change(hour: 15, min: 0)
  )
  booking_ananya.update_column(:aasm_state, "confirmed")
  booking_ananya.update_column(:payment_status, "paid")

  Review.create!(
    tenant:     tenant,
    reviewable: booking_priya,
    reviewer:   raj,
    reviewee:   priya,
    rating:     5,
    content:    "Dr. Priya was incredibly thorough and compassionate. She explained everything clearly and I left the consultation feeling confident about my treatment plan."
  )

  Review.create!(
    tenant:     tenant,
    reviewable: booking_rahul,
    reviewer:   raj,
    reviewee:   rahul,
    rating:     5,
    content:    "Excellent cardiology consultation. Dr. Rahul spotted a concern in my ECG that two other doctors had missed. Highly knowledgeable and reassuring."
  )

  Review.create!(
    tenant:     tenant,
    reviewable: booking_ananya,
    reviewer:   raj,
    reviewee:   ananya,
    rating:     4,
    content:    "Wonderful session with Dr. Ananya. She provided practical CBT tools I could use immediately. I felt genuinely heard throughout the session."
  )

  puts "  Bookings: 3 historical completed bookings created"
  puts "  Reviews: 3 reviews created (5★, 5★, 4★)"
else
  puts "  Bookings/Reviews: already exist, skipped"
end

puts "\n=== SOS My Doctor demo seed complete ==="
puts ""
puts "  Login credentials:"
puts "    Admin    : admin@sosmydoctor.com   / Demo1234!"
puts "    Expert 1 : dr.priya@sosmydoctor.com  / Demo1234!"
puts "    Expert 2 : dr.rahul@sosmydoctor.com  / Demo1234!"
puts "    Expert 3 : dr.ananya@sosmydoctor.com / Demo1234!"
puts "    Client   : patient@example.com     / Demo1234!"
puts ""
