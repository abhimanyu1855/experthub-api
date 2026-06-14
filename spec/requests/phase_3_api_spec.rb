# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Phase 3 API Endpoints", type: :request do
  let!(:tenant) { create(:tenant) }
  
  let!(:client_user) { create(:user, :confirmed) }
  let!(:client_membership) { create(:membership, user: client_user, tenant: tenant, role: :client) }

  let!(:expert_user) { create(:user, :confirmed) }
  let!(:expert_membership) { create(:membership, user: expert_user, tenant: tenant, role: :expert) }
  let!(:expert_profile) { create(:expert_profile, user: expert_user, tenant: tenant) }

  let!(:operator_user) { create(:user, :confirmed) }
  let!(:operator_membership) { create(:membership, user: operator_user, tenant: tenant, role: :operator) }

  # Helper to generate authenticated headers
  def auth_headers(user)
    post "/login", params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }, headers: { "X-Tenant-Id" => tenant.ident }

    expect(response).to have_http_status(:ok)
    auth_token = response.headers["Authorization"]
    {
      "Authorization" => auth_token,
      "X-Tenant-Id" => tenant.ident,
      "Accept" => "application/json"
    }
  end

  describe "Courses & Lessons API" do
    let!(:course) { create(:course, tenant: tenant, expert_profile: expert_profile) }
    let!(:lesson1) { create(:lesson, course: course, sort_priority: 1) }
    let!(:lesson2) { create(:lesson, course: course, sort_priority: 2) }
    let!(:quiz) { create(:lesson_quiz, lesson: lesson2, title: "Final Lesson Quiz") }
    let!(:question) { create(:quiz_question, quiz: quiz) }
    let!(:correct_option) { create(:quiz_option, question: question, is_correct: true, option_text: "rails new") }
    let!(:incorrect_option) { create(:quiz_option, question: question, is_correct: false, option_text: "rails generate") }

    it "lists and shows courses" do
      get "/courses", headers: { "X-Tenant-Id" => tenant.ident }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)

      get "/courses/#{course.id}", headers: { "X-Tenant-Id" => tenant.ident }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq(course.title)
      expect(json["lessons"].size).to eq(2)
    end

    it "allows experts to create courses" do
      headers = auth_headers(expert_user)
      post "/courses", params: {
        course: {
          title: "Advanced React Patterns",
          description: "Master React context, hooks, and performance.",
          price_cents: 9900,
          currency: "USD",
          is_active: true
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["title"]).to eq("Advanced React Patterns")
    end

    it "enrolls clients, tracks progress, and validates quiz submission" do
      headers = auth_headers(client_user)

      # Enroll in course
      post "/courses/#{course.id}/enroll", headers: headers
      expect(response).to have_http_status(:created)
      enrollment_json = JSON.parse(response.body)
      expect(enrollment_json["status"]).to eq("active")

      # Complete first lesson
      post "/lessons/#{lesson1.id}/complete", headers: headers
      expect(response).to have_http_status(:ok)
      complete_json = JSON.parse(response.body)
      expect(complete_json["enrollment_status"]).to eq("active")
      expect(complete_json["certificate"]).to be_nil

      # Submit incorrect quiz answer
      post "/lessons/#{lesson2.id}/quiz/submit", params: {
        answers: { question.id.to_s => incorrect_option.id.to_s }
      }, headers: headers
      expect(response).to have_http_status(:ok)
      quiz_json = JSON.parse(response.body)
      expect(quiz_json["passed"]).to eq(false)

      # Submit correct quiz answer
      post "/lessons/#{lesson2.id}/quiz/submit", params: {
        answers: { question.id.to_s => correct_option.id.to_s }
      }, headers: headers
      expect(response).to have_http_status(:ok)
      quiz_json = JSON.parse(response.body)
      expect(quiz_json["passed"]).to eq(true)
      expect(quiz_json["enrollment_status"]).to eq("completed")
      expect(quiz_json["certificate"]).to be_present
    end
  end

  describe "Group Sessions API" do
    it "creates group sessions and handles user registrations" do
      expert_headers = auth_headers(expert_user)
      
      post "/group_sessions", params: {
        group_session: {
          title: "Rails 8 Real-time Q&A",
          description: "Come ask anything about ActionCable and SolidQueue.",
          start_time: (Time.current + 2.hours).iso8601,
          end_time: (Time.current + 3.hours).iso8601,
          price_cents: 1500,
          currency: "USD",
          max_participants: 5
        }
      }, headers: expert_headers

      expect(response).to have_http_status(:created)
      gs_json = JSON.parse(response.body)
      expect(gs_json["video_room_url"]).to be_present

      # List active group sessions
      get "/group_sessions", headers: { "X-Tenant-Id" => tenant.ident }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)

      # Register user
      client_headers = auth_headers(client_user)
      post "/group_sessions/#{gs_json["id"]}/register", headers: client_headers
      expect(response).to have_http_status(:created)
      reg_json = JSON.parse(response.body)
      expect(reg_json["status"]).to eq("registered")
    end
  end

  describe "Booking Packages API" do
    it "creates and purchases packages" do
      expert_headers = auth_headers(expert_user)

      post "/booking_packages", params: {
        booking_package: {
          title: "Mentorship Bundle 10x",
          description: "10 hours of dedicated pair programming.",
          price_cents: 80000,
          currency: "USD",
          booking_count: 10
        }
      }, headers: expert_headers

      expect(response).to have_http_status(:created)
      bp_json = JSON.parse(response.body)
      expect(bp_json["booking_count"]).to eq(10)

      # Purchase package
      client_headers = auth_headers(client_user)
      post "/booking_packages/#{bp_json["id"]}/purchase", headers: client_headers
      expect(response).to have_http_status(:created)
      purch_json = JSON.parse(response.body)
      expect(purch_json["remaining_bookings"]).to eq(10)
    end
  end

  describe "Subscriptions API" do
    it "manages plans and subscription life cycles" do
      operator_headers = auth_headers(operator_user)

      # Create Plan
      post "/subscription_plans", params: {
        subscription_plan: {
          name: "VIP Expert Tier",
          price_cents: 29900,
          currency: "USD",
          billing_interval: "monthly",
          target_role: "expert"
        }
      }, headers: operator_headers
      expect(response).to have_http_status(:created)
      plan_json = JSON.parse(response.body)

      # List Plans
      get "/subscription_plans", headers: { "X-Tenant-Id" => tenant.ident }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)

      # Subscribe
      expert_headers = auth_headers(expert_user)
      post "/subscriptions", params: { subscription_plan_id: plan_json["id"] }, headers: expert_headers
      expect(response).to have_http_status(:created)
      sub_json = JSON.parse(response.body)
      expect(sub_json["status"]).to eq("active")

      # Cancel subscription
      post "/subscriptions/#{sub_json["id"]}/cancel", headers: expert_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["status"]).to eq("canceled")
    end
  end

  describe "Promo Codes API" do
    let!(:promo) { create(:promo_code, tenant: tenant, code: "SUMMER20", discount_type: "percent", discount_value: 20.0) }

    it "validates promo code discount calculation" do
      post "/promo_codes/validate", params: {
        code: "SUMMER20",
        price_cents: 10000
      }, headers: { "X-Tenant-Id" => tenant.ident }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["valid"]).to eq(true)
      expect(json["discount_cents"]).to eq(2000)
      expect(json["final_price_cents"]).to eq(8000)
    end

    it "returns error for invalid/missing promo codes" do
      post "/promo_codes/validate", params: {
        code: "INVALID_CODE",
        price_cents: 10000
      }, headers: { "X-Tenant-Id" => tenant.ident }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["valid"]).to eq(false)
    end
  end

  describe "CMS Pages API" do
    let!(:cms_page) { create(:page, tenant: tenant, slug: "terms-and-conditions", is_published: true) }

    it "allows public fetching of published page contents" do
      get "/pages/terms-and-conditions", headers: { "X-Tenant-Id" => tenant.ident }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["slug"]).to eq("terms-and-conditions")
    end

    it "returns 404 for missing pages" do
      get "/pages/non-existent-page", headers: { "X-Tenant-Id" => tenant.ident }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Checkout Fields API" do
    it "allows operators to configure custom checkout fields" do
      operator_headers = auth_headers(operator_user)

      post "/checkout_fields", params: {
        checkout_field: {
          field_name: "Github Profile URL",
          field_type: "text",
          required: true
        }
      }, headers: operator_headers
      expect(response).to have_http_status(:created)

      get "/checkout_fields", headers: { "X-Tenant-Id" => tenant.ident }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end
  end
end
