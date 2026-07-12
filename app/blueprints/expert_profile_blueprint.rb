# frozen_string_literal: true

class ExpertProfileBlueprint < Blueprinter::Base
  identifier :id

  fields :user_id, :specialization, :bio, :title, :timezone_offset, :default_slot_duration, :is_on_duty, :approval_status, :average_rating, :reviews_count, :bookings_count, :payout_connected, :payout_onboarding_started, :payout_status, :press_links, :credentials, :intro_video_url

  association :user, blueprint: SimpleUserBlueprint

  view :normal do
    fields :specialization, :bio, :title, :average_rating, :payout_connected, :payout_onboarding_started, :payout_status, :press_links, :credentials, :intro_video_url
  end
end
