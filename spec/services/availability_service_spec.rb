# frozen_string_literal: true

require "rails_helper"

RSpec.describe AvailabilityService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:expert) { create(:user) }
  let(:expert_profile) { create(:expert_profile, user: expert, tenant: tenant) }
  let(:category) { create(:category, tenant: tenant) }
  let(:service) { create(:service, expert_profile: expert_profile, tenant: tenant, category: category, duration_minutes: 30, slot_interval_minutes: 30) }
  
  let(:date) { Date.current + 7.days }

  before do
    create(:working_time_slot, expert_profile: expert_profile, week_day: date.cwday, from_time: "09:00", till_time: "11:00")
  end

  describe ".available_slots" do
    it "generates slots within working hours" do
      slots = described_class.available_slots(service: service, date: date)

      # 09:00 - 11:00 with 30m slots should yield:
      # 1. 09:00 - 09:30
      # 2. 09:30 - 10:00
      # 3. 10:00 - 10:30
      # 4. 10:30 - 11:00
      expect(slots.size).to eq(4)
      expect(slots[0][:start_time].strftime("%H:%M")).to eq("09:00")
      expect(slots[3][:end_time].strftime("%H:%M")).to eq("11:00")
      expect(slots.all? { |s| s[:available] }).to be true
    end

    it "marks slots as unavailable if they overlap with a booked session" do
      start_time = date.in_time_zone.change(hour: 9, min: 30)
      end_time = date.in_time_zone.change(hour: 10, min: 0)
      
      create(:booking, service: service, expert: expert, start_time: start_time, end_time: end_time, aasm_state: "paid")

      slots = described_class.available_slots(service: service, date: date)

      # Slot 09:30 - 10:00 should be unavailable
      expect(slots[0][:available]).to be true  # 09:00 - 09:30
      expect(slots[1][:available]).to be false # 09:30 - 10:00 (booked!)
      expect(slots[2][:available]).to be true  # 10:00 - 10:30
      expect(slots[3][:available]).to be true  # 10:30 - 11:00
    end

    it "marks slots as unavailable when a group session overlaps" do
      create(:group_session, expert_profile: expert_profile, tenant: tenant,
             start_time: date.in_time_zone.change(hour: 9, min: 30),
             end_time: date.in_time_zone.change(hour: 10, min: 0))

      slots = described_class.available_slots(service: service, date: date)
      expect(slots[1][:available]).to be false
    end

    it "marks slots as unavailable when a pending checkout overlaps" do
      create(:booking, service: service, expert: expert, tenant: tenant,
             start_time: date.in_time_zone.change(hour: 9, min: 30),
             end_time: date.in_time_zone.change(hour: 10, min: 0),
             aasm_state: "payment_initiated")

      slots = described_class.available_slots(service: service, date: date)
      expect(slots[1][:available]).to be false
    end

    it "allows a client to see the slot as available if the checkout hold belongs to them" do
      client = create(:user)
      create(:booking, service: service, expert: expert, tenant: tenant, client: client,
             start_time: date.in_time_zone.change(hour: 9, min: 30),
             end_time: date.in_time_zone.change(hour: 10, min: 0),
             aasm_state: "payment_initiated")

      # Without passing client_id, the slot is blocked
      slots = described_class.available_slots(service: service, date: date)
      expect(slots[1][:available]).to be false

      # With passing client_id, the slot is available
      slots_with_client = described_class.available_slots(service: service, date: date, client_id: client.id)
      expect(slots_with_client[1][:available]).to be true
    end

    it "returns empty array if the date is blocked" do
      create(:blocked_date, service: service, blocked_on: date)

      slots = described_class.available_slots(service: service, date: date)
      expect(slots).to be_empty
    end
  end
end
