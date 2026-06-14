# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Phase 3 Models", type: :model do
  let(:tenant) { create(:tenant) }
  let(:expert) { create(:user) }
  let!(:expert_profile) { create(:expert_profile, user: expert, tenant: tenant) }
  let(:client) { create(:user) }

  describe Course do
    it "requires a title and price" do
      course = build(:course, title: nil, tenant: tenant, expert_profile: expert_profile)
      expect(course).not_to be_valid
    end
  end

  describe Enrollment do
    let!(:course) { create(:course, tenant: tenant, expert_profile: expert_profile) }
    let!(:lesson1) { create(:lesson, course: course, sort_priority: 1) }
    let!(:lesson2) { create(:lesson, course: course, sort_priority: 2) }
    
    it "automatically completes enrollment and issues certificate when all lessons are complete" do
      enrollment = create(:enrollment, course: course, user: client, tenant: tenant)
      expect(enrollment.status).to eq("active")
      expect(enrollment.certificate).to be_nil

      # Complete first lesson
      create(:lesson_progress, enrollment: enrollment, lesson: lesson1)
      expect(enrollment.reload.status).to eq("active")

      # Complete second lesson (should trigger completion)
      create(:lesson_progress, enrollment: enrollment, lesson: lesson2)
      
      enrollment.reload
      expect(enrollment.status).to eq("completed")
      expect(enrollment.certificate).to be_present
      expect(enrollment.certificate.certificate_code).to start_with("CERT-")
    end
  end

  describe GroupSession do
    it "validates that end_time is after start_time" do
      session = build(:group_session,
        tenant: tenant,
        expert_profile: expert_profile,
        start_time: Time.current + 2.hours,
        end_time: Time.current + 1.hour
      )
      expect(session).not_to be_valid
    end
  end

  describe SessionAttendance do
    let!(:group_session) do
      create(:group_session,
        tenant: tenant,
        expert_profile: expert_profile,
        max_participants: 1,
        start_time: Time.current + 1.hour,
        end_time: Time.current + 2.hours
      )
    end

    it "prevents registering if session capacity is reached" do
      user1 = create(:user)
      user2 = create(:user)

      create(:session_attendance, group_session: group_session, user: user1, status: "registered")
      
      attendance2 = build(:session_attendance, group_session: group_session, user: user2, status: "registered")
      expect(attendance2).not_to be_valid
      expect(attendance2.errors[:base]).to include("This group session is already full")
    end
  end

  describe PromoCode do
    it "calculates correct discount amounts" do
      percent_promo = create(:promo_code, tenant: tenant, discount_type: "percent", discount_value: 20.0)
      fixed_promo = create(:promo_code, tenant: tenant, discount_type: "fixed", discount_value: 10.0) # $10 discount

      expect(percent_promo.calculate_discount(5000)).to eq(1000) # 20% of 5000 is 1000
      expect(fixed_promo.calculate_discount(5000)).to eq(1000) # $10 is 1000 cents
      expect(fixed_promo.calculate_discount(500)).to eq(500) # discount capped at item price
    end
  end

  describe BookingPackage do
    it "requires title, price, and positive booking count" do
      package = build(:booking_package, title: nil, tenant: tenant, expert_profile: expert_profile)
      expect(package).not_to be_valid

      package = build(:booking_package, booking_count: 0, tenant: tenant, expert_profile: expert_profile)
      expect(package).not_to be_valid
    end
  end

  describe PackagePurchase do
    let(:package) { create(:booking_package, tenant: tenant, expert_profile: expert_profile, booking_count: 2) }

    it "decrements remaining bookings and raises error when empty" do
      purchase = create(:package_purchase, booking_package: package, user: client, tenant: tenant, remaining_bookings: 2)
      purchase.use_booking!
      expect(purchase.remaining_bookings).to eq(1)

      purchase.use_booking!
      expect(purchase.remaining_bookings).to eq(0)

      expect { purchase.use_booking! }.to raise_error("No remaining bookings left in this package purchase")
    end
  end

  describe SubscriptionPlan do
    it "validates interval and target role" do
      plan = build(:subscription_plan, billing_interval: "daily", tenant: tenant)
      expect(plan).not_to be_valid

      plan = build(:subscription_plan, target_role: "admin", tenant: tenant)
      expect(plan).not_to be_valid
    end
  end

  describe Subscription do
    let(:plan) { create(:subscription_plan, tenant: tenant) }

    it "validates status and handles cancellation" do
      sub = build(:subscription, subscription_plan: plan, user: client, tenant: tenant, status: "expired")
      expect(sub).not_to be_valid

      sub = create(:subscription, subscription_plan: plan, user: client, tenant: tenant, status: "active")
      expect(sub).to be_active
      sub.cancel!
      expect(sub.reload.status).to eq("canceled")
      expect(sub).not_to be_active
    end
  end

  describe CheckoutField do
    it "validates field_type" do
      field = build(:checkout_field, tenant: tenant, field_type: "boolean")
      expect(field).not_to be_valid
    end
  end

  describe CheckoutFieldValue do
    let(:service) { create(:service, tenant: tenant, expert_profile: expert_profile) }
    let(:booking) { create(:booking, service: service, client: client, tenant: tenant) }
    let(:field) { create(:checkout_field, tenant: tenant) }

    it "enforces uniqueness of field per booking" do
      create(:checkout_field_value, checkout_field: field, booking: booking, value: "First Value")
      duplicate = build(:checkout_field_value, checkout_field: field, booking: booking, value: "Second Value")
      expect(duplicate).not_to be_valid
    end
  end

  describe Page do
    it "requires unique slug per tenant" do
      create(:page, tenant: tenant, slug: "test-slug")
      duplicate = build(:page, tenant: tenant, slug: "test-slug")
      expect(duplicate).not_to be_valid
    end
  end
end

