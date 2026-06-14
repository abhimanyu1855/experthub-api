# frozen_string_literal: true

class ServiceBlueprint < Blueprinter::Base
  identifier :id

  fields :title, :description, :price_cents, :currency, :duration_minutes, :slot_interval_minutes, :booking_buffer_minutes, :allow_multiple_bookings, :max_concurrent_bookings, :approval_status, :is_active

  association :expert_profile, blueprint: ExpertProfileBlueprint
  association :category, blueprint: CategoryBlueprint
end
