# frozen_string_literal: true

require 'active_job'
ActiveJob::Base.queue_adapter = :test

# test_flow_scratch.rb
# This script creates a marketplace, configures it, sets up experts, registers a client, and books a service.

puts "=========================================================="
puts "🚀 STARTING E2E FLOW TEST FOR SOSMYDOCTOR"
puts "=========================================================="

# 1. Create a new marketplace (Tenant)
tenant = Tenant.find_by(ident: 'sosmydoctor')
if tenant
  puts "Marketplace SOSMYDOCTOR already exists. Cleaning up existing records for a fresh test..."
  tenant.bookings.destroy_all rescue nil
  tenant.services.destroy_all rescue nil
  tenant.categories.destroy_all rescue nil
  tenant.expert_applications.destroy_all rescue nil
  tenant.working_time_slots.destroy_all rescue nil
  
  User.where(email: [
    'admin@sosmydoctor.com',
    'alice.smith@sosmydoctor.com',
    'bob.brown@sosmydoctor.com',
    'charlie.green@gmail.com'
  ]).destroy_all rescue nil

  tenant.destroy!
end


puts "1. Creating Tenant 'sosmydoctor'..."
tenant = Tenant.create!(
  ident: 'sosmydoctor',
  name: 'SOSMYDOCTOR',
  default_currency: 'USD',
  seller_commission_pct: 15.0,
  buyer_commission_pct: 2.0,
  settings: {
    slogan: "On-demand expert medical consultations"
  }
)

# Create setup steps
%w[name brand payments domain landing experts].each_with_index do |step_id, idx|
  tenant.tenant_setup_steps.create!(
    step_id: step_id,
    completed: true,
    active: false
  )
end

puts "✅ Tenant created: #{tenant.name} (ID: #{tenant.id})"

# 2. Create Admin User & Tenant Membership
puts "\n2. Creating Admin user..."
admin_user = User.create!(
  email: 'admin@sosmydoctor.com',
  password: 'password123',
  password_confirmation: 'password123',
  given_name: 'John',
  family_name: 'Doe',
  display_name: 'Dr. John Doe (Admin)'
)
admin_user.skip_confirmation! if admin_user.respond_to?(:skip_confirmation!)
admin_user.save!

Membership.create!(
  user: admin_user,
  tenant: tenant,
  role: 'operator',
  status: 'active'
)
puts "✅ Admin user created: #{admin_user.email}"

# Update Stripe Key on the tenant (simulating admin action)
puts "\n3. Simulating Admin setting Stripe API key..."
tenant.update!(
  settings: tenant.settings.merge(stripe_api_key: 'sk_test_sosmydoctormockkey123')
)
puts "✅ Tenant updated with Stripe Key: #{tenant.settings['stripe_api_key']}"

# Create Medical Categories
puts "\n4. Creating service categories..."
cardiology_cat = Category.create!(tenant: tenant, name: 'Cardiology', category_type: 'service')
dermatology_cat = Category.create!(tenant: tenant, name: 'Dermatology', category_type: 'service')
puts "✅ Categories created: '#{cardiology_cat.name}' and '#{dermatology_cat.name}'"

# 5. Create Expert 1 (Cardiologist)
puts "\n5. Registering Cardiologist expert..."
doc_alice = User.create!(
  email: 'alice.smith@sosmydoctor.com',
  password: 'password123',
  password_confirmation: 'password123',
  given_name: 'Alice',
  family_name: 'Smith',
  display_name: 'Dr. Alice Smith'
)
doc_alice.skip_confirmation! if doc_alice.respond_to?(:skip_confirmation!)
doc_alice.save!

Membership.create!(
  user: doc_alice,
  tenant: tenant,
  role: 'expert',
  status: 'active'
)

# Submit application
app_alice = tenant.expert_applications.create!(
  user: doc_alice,
  status: 'pending',
  application_data: {
    'headline' => 'Consultant Cardiologist',
    'expertise' => 'Cardiology',
    'bio' => '20+ years of experience in cardiology. Former Chief of Cardiac Surgery at NY General.',
    'experience' => '20 years',
    'hourly_rate' => '200'
  }
)

# Approve application
app_alice.update!(status: 'approved')
profile_alice = ExpertProfile.create!(
  user: doc_alice,
  tenant: tenant,
  specialization: 'Cardiology',
  title: 'Consultant Cardiologist',
  bio: app_alice.application_data['bio'],
  approval_status: 'approved',
  is_on_duty: true
)

# Create Service for Cardiologist
service_alice = Service.create!(
  expert_profile: profile_alice,
  tenant: tenant,
  category: cardiology_cat,
  title: 'Cardiovascular Risk Assessment',
  description: 'Full heart health and cardiovascular consultation including lifestyle audits.',
  price_cents: 20000, # $200.00
  duration_minutes: 60,
  approval_status: :approved,
  is_active: true
)

# Set Working Hours for Cardiologist
(1..5).each do |day|
  WorkingTimeSlot.create!(
    expert_profile: profile_alice,
    week_day: day,
    from_time: "09:00",
    till_time: "17:00",
    is_active: true
  )
end

puts "✅ Doctor 1: Dr. Alice Smith registered, approved, service '#{service_alice.title}' created, and working hours scheduled."

# 6. Create Expert 2 (Dermatologist)
puts "\n6. Registering Dermatologist expert..."
doc_bob = User.create!(
  email: 'bob.brown@sosmydoctor.com',
  password: 'password123',
  password_confirmation: 'password123',
  given_name: 'Bob',
  family_name: 'Brown',
  display_name: 'Dr. Bob Brown'
)
doc_bob.skip_confirmation! if doc_bob.respond_to?(:skip_confirmation!)
doc_bob.save!

Membership.create!(
  user: doc_bob,
  tenant: tenant,
  role: 'expert',
  status: 'active'
)

# Submit application
app_bob = tenant.expert_applications.create!(
  user: doc_bob,
  status: 'pending',
  application_data: {
    'headline' => 'Consultant Dermatologist',
    'expertise' => 'Dermatology',
    'bio' => 'Board-certified dermatologist specializing in clinical dermatology and acne treatments.',
    'experience' => '12 years',
    'hourly_rate' => '150'
  }
)

# Approve application
app_bob.update!(status: 'approved')
profile_bob = ExpertProfile.create!(
  user: doc_bob,
  tenant: tenant,
  specialization: 'Dermatology',
  title: 'Consultant Dermatologist',
  bio: app_bob.application_data['bio'],
  approval_status: 'approved',
  is_on_duty: true
)

# Create Service for Dermatologist
service_bob = Service.create!(
  expert_profile: profile_bob,
  tenant: tenant,
  category: dermatology_cat,
  title: 'Skin Consultation & Acne Audit',
  description: 'Consultation covering acne treatment, prescription options, and skincare regimes.',
  price_cents: 15000, # $150.00
  duration_minutes: 45,
  approval_status: :approved,
  is_active: true
)

# Set Working Hours for Dermatologist
(1..5).each do |day|
  WorkingTimeSlot.create!(
    expert_profile: profile_bob,
    week_day: day,
    from_time: "10:00",
    till_time: "16:00",
    is_active: true
  )
end

puts "✅ Doctor 2: Dr. Bob Brown registered, approved, service '#{service_bob.title}' created, and working hours scheduled."

# 7. Create Customer & Book Doctor 1
puts "\n7. Registering new Customer..."
customer_charlie = User.create!(
  email: 'charlie.green@gmail.com',
  password: 'password123',
  password_confirmation: 'password123',
  given_name: 'Charlie',
  family_name: 'Green',
  display_name: 'Charlie Green'
)
customer_charlie.skip_confirmation! if customer_charlie.respond_to?(:skip_confirmation!)
customer_charlie.save!

Membership.create!(
  user: customer_charlie,
  tenant: tenant,
  role: 'client',
  status: 'active'
)
puts "✅ Customer created: #{customer_charlie.email}"

# Book Dr. Alice Smith
puts "\n8. Simulating booking flow for Dr. Alice Smith..."
start_time = Time.zone.now.change(hour: 10, min: 0) + 1.day
end_time = start_time + 1.hour

booking = BookingService.create(
  service: service_alice,
  client: customer_charlie,
  start_time: start_time,
  end_time: end_time,
  tenant: tenant
)

puts "✅ Booking record initialized (ID: #{booking.id}, initial state: #{booking.aasm_state})"

# Simulate successful Stripe checkout payment on the booking
BookingService.payment_succeeded(
  booking: booking,
  stripe_payment_intent_id: "pi_sosmydoctor_test_12345"
)
puts "✅ Payment succeeded hook invoked! Booking state: #{booking.reload.aasm_state}"

# Confirm booking as Doctor 1 / Admin
booking.confirm!
CreateVideoRoomJob.perform_now(booking.id) if defined?(CreateVideoRoomJob)
puts "✅ Booking confirmed and Daily.co video room generated! Final state: #{booking.reload.aasm_state}"
puts "📹 Video room URL: #{booking.video_room_url}"

puts "\n=========================================================="
puts "🎉 E2E FLOW TEST FOR SOSMYDOCTOR COMPLETED SUCCESSFULLY!"
puts "=========================================================="
