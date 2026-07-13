# frozen_string_literal: true

class AnalyticsController < ApplicationController
  before_action :require_operator!, only: [:dashboard]
  before_action :require_expert!, only: [:expert]

  # GET /analytics/dashboard
  def dashboard
    bookings_sales = current_tenant.bookings.confirmed_or_paid.sum(:price_cents)
    packages_sales = current_tenant.package_purchases.joins(:booking_package).sum("booking_packages.price_cents")
    subscriptions_sales = current_tenant.subscriptions.joins(:subscription_plan).sum("subscription_plans.price_cents")

    total_sales_cents = bookings_sales + packages_sales + subscriptions_sales
    total_commission_cents = current_tenant.bookings.confirmed_or_paid.sum(:commission_cents)
    active_users_count = current_tenant.users.count
    total_bookings_count = current_tenant.bookings.count
    active_experts_count = current_tenant.expert_profiles.approved.count
    active_clients_count = [active_users_count - active_experts_count, 0].max

    top_categories = current_tenant.bookings.confirmed_or_paid
      .joins(service: :category)
      .group("categories.name")
      .count

    revenue_by_month = (5.downto(0)).map do |i|
      start_of_month = i.months.ago.beginning_of_month
      end_of_month   = i.months.ago.end_of_month
      month_bookings = current_tenant.bookings.confirmed_or_paid
        .where(created_at: start_of_month..end_of_month)
      {
        month: start_of_month.strftime("%b"),
        revenue_cents: month_bookings.sum(:price_cents),
        bookings_count: month_bookings.count
      }
    end

    top_experts = current_tenant.bookings.confirmed_or_paid
      .joins("INNER JOIN users ON users.id = bookings.expert_id")
      .joins(
        ActiveRecord::Base.sanitize_sql_array([
          "INNER JOIN expert_profiles ON expert_profiles.user_id = bookings.expert_id AND expert_profiles.tenant_id = ?",
          current_tenant.id
        ])
      )
      .group("users.id, users.given_name, users.family_name, expert_profiles.specialization, expert_profiles.average_rating")
      .select("users.id, users.given_name, users.family_name, expert_profiles.specialization, expert_profiles.average_rating, COUNT(bookings.id) AS bookings_count, SUM(bookings.price_cents) AS revenue_cents")
      .order("bookings_count DESC")
      .limit(5)
      .map do |r|
        {
          name: "#{r.given_name} #{r.family_name}".strip,
          specialization: r.specialization || "Expert",
          bookings: r.bookings_count.to_i,
          revenue_cents: r.revenue_cents.to_i,
          rating: r.average_rating.to_f
        }
      end

    recent_bookings = current_tenant.bookings
      .confirmed_or_paid
      .joins("INNER JOIN users AS clients ON clients.id = bookings.client_id")
      .joins("INNER JOIN users AS experts ON experts.id = bookings.expert_id")
      .select("bookings.*, clients.given_name AS client_first_name, clients.family_name AS client_last_name, experts.given_name AS expert_first_name, experts.family_name AS expert_last_name")
      .order(created_at: :desc)
      .limit(5)
      .map do |b|
        {
          id: b.id,
          client: "#{b.client_first_name} #{b.client_last_name}".strip,
          expert: "#{b.expert_first_name} #{b.expert_last_name}".strip,
          price_cents: b.price_cents,
          aasm_state: b.aasm_state,
          created_at: b.created_at
        }
      end

    render json: {
      total_sales_cents: total_sales_cents,
      total_commission_cents: total_commission_cents,
      active_users_count: active_users_count,
      active_experts_count: active_experts_count,
      active_clients_count: active_clients_count,
      total_bookings_count: total_bookings_count,
      top_categories: top_categories,
      revenue_by_month: revenue_by_month,
      top_experts: top_experts,
      recent_bookings: recent_bookings
    }
  end

  # GET /analytics/expert
  def expert
    expert_profile = current_user.expert_profile
    return render json: { error: "Expert profile not found" }, status: :not_found unless expert_profile

    # 1:1 Bookings
    bookings = current_tenant.bookings.where(expert: current_user)
    expert_bookings_count = bookings.count
    one_on_one_sales_cents = bookings.confirmed_or_paid.sum(:price_cents)
    one_on_one_payout_cents = bookings.confirmed_or_paid.sum(:expert_payout_cents)
    one_on_one_commission_cents = bookings.confirmed_or_paid.sum(:commission_cents)

    # Commission settings
    rate = current_tenant.seller_commission_pct
    commission_model = current_tenant.setting("commission_model", "percentage")

    # Courses
    course_sales_cents = current_tenant.enrollments.joins(:course)
      .where(courses: { expert_profile: expert_profile })
      .sum("courses.price_cents")
    course_enrollments_count = current_tenant.enrollments.joins(:course)
      .where(courses: { expert_profile: expert_profile })
      .count

    if commission_model == "flat"
      course_commission_cents = course_enrollments_count * current_tenant.setting("commission_flat_fee_cents", 0).to_i
    else
      course_commission_cents = (course_sales_cents * rate / 100.0).round
    end
    course_payout_cents = course_sales_cents - course_commission_cents

    # Group Sessions (1-to-many)
    group_session_sales_cents = current_tenant.group_sessions.where(expert_profile: expert_profile)
      .joins(:attendances)
      .where(session_attendances: { status: %w[registered attended] })
      .sum("group_sessions.price_cents")
    group_attendees_count = current_tenant.group_sessions.where(expert_profile: expert_profile)
      .joins(:attendances)
      .where(session_attendances: { status: %w[registered attended] })
      .count

    if commission_model == "flat"
      group_commission_cents = group_attendees_count * current_tenant.setting("commission_flat_fee_cents", 0).to_i
    else
      group_commission_cents = (group_session_sales_cents * rate / 100.0).round
    end
    group_session_payout_cents = group_session_sales_cents - group_commission_cents

    # Totals
    expert_sales_cents = one_on_one_sales_cents + course_sales_cents + group_session_sales_cents
    expert_payout_cents = one_on_one_payout_cents + course_payout_cents + group_session_payout_cents

    # Earnings by month (last 6 months)
    earnings_by_month = (5.downto(0)).map do |i|
      start_of_month = i.months.ago.beginning_of_month
      end_of_month   = i.months.ago.end_of_month
      month_earnings = current_tenant.bookings
        .where(expert: current_user)
        .confirmed_or_paid
        .where(created_at: start_of_month..end_of_month)
        .sum(:expert_payout_cents)
      {
        month: start_of_month.strftime("%b"),
        earnings_cents: month_earnings
      }
    end

    # Upcoming bookings
    upcoming_bookings = current_tenant.bookings
      .where(expert: current_user)
      .upcoming
      .limit(5)
      .map { |b| { id: b.id, start_time: b.start_time, aasm_state: b.aasm_state } }

    render json: {
      expert_bookings_count: expert_bookings_count,
      ratings_average: expert_profile.average_rating.to_f,

      one_on_one_sales_cents: one_on_one_sales_cents,
      one_on_one_payout_cents: one_on_one_payout_cents,
      one_on_one_commission_cents: one_on_one_commission_cents,

      course_sales_cents: course_sales_cents,
      course_payout_cents: course_payout_cents,
      course_commission_cents: course_commission_cents,

      group_session_sales_cents: group_session_sales_cents,
      group_session_payout_cents: group_session_payout_cents,
      group_session_commission_cents: group_commission_cents,

      expert_sales_cents: expert_sales_cents,
      expert_payout_cents: expert_payout_cents,
      earnings_by_month: earnings_by_month,
      upcoming_bookings: upcoming_bookings
    }
  end
end
