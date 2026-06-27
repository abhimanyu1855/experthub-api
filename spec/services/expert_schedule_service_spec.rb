# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExpertScheduleService do
  let(:tenant) { create(:tenant) }
  let(:expert_profile) { create(:expert_profile, tenant: tenant) }
  let(:service) { create(:service, expert_profile: expert_profile, tenant: tenant) }
  let(:client) { create(:user) }
  let(:start_time) { Time.current + 1.day + 2.hours }
  let(:end_time) { start_time + 1.hour }

  describe ".slot_taken?" do
    it "returns true when a paid booking overlaps" do
      create(:booking, service: service, expert: expert_profile.user, tenant: tenant, client: client,
             start_time: start_time, end_time: end_time, aasm_state: "paid")

      expect(described_class.slot_taken?(expert_profile: expert_profile, start_time: start_time, end_time: end_time)).to be true
    end

    it "returns true when a recent pending booking overlaps" do
      create(:booking, service: service, expert: expert_profile.user, tenant: tenant, client: client,
             start_time: start_time, end_time: end_time, aasm_state: "pending")

      expect(described_class.slot_taken?(expert_profile: expert_profile, start_time: start_time, end_time: end_time)).to be true
    end

    it "returns true when a group session overlaps" do
      create(:group_session, expert_profile: expert_profile, tenant: tenant,
             start_time: start_time, end_time: end_time)

      expect(described_class.slot_taken?(expert_profile: expert_profile, start_time: start_time, end_time: end_time)).to be true
    end

    it "returns false when only an expired pending hold overlaps" do
      create(:booking, service: service, expert: expert_profile.user, tenant: tenant, client: client,
             start_time: start_time, end_time: end_time, aasm_state: "pending", created_at: 31.minutes.ago)

      expect(described_class.slot_taken?(expert_profile: expert_profile, start_time: start_time, end_time: end_time)).to be false
    end
  end
end
