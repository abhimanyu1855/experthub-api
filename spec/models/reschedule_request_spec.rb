# frozen_string_literal: true

require "rails_helper"

RSpec.describe RescheduleRequest, type: :model do
  let(:tenant) { create(:tenant) }
  let(:client) { create(:user, :confirmed) }
  let(:expert) { create(:user, :confirmed) }
  let(:expert_profile) { create(:expert_profile, user: expert, tenant: tenant) }
  let(:service) { create(:service, expert_profile: expert_profile, tenant: tenant) }
  
  let!(:booking) do
    create(:booking,
      tenant: tenant,
      service: service,
      client: client,
      expert: expert,
      start_time: Time.current + 2.hours,
      end_time: Time.current + 3.hours,
      aasm_state: "paid"
    )
  end

  describe "validations" do
    it "requires start_time, end_time, and status" do
      req = build(:reschedule_request, booking: booking, tenant: tenant, requested_by: client, new_start_time: nil)
      expect(req).not_to be_valid
    end

    it "requires new_end_time to be after new_start_time" do
      req = build(:reschedule_request,
        booking: booking,
        tenant: tenant,
        requested_by: client,
        new_start_time: Time.current + 3.hours,
        new_end_time: Time.current + 2.hours
      )
      expect(req).not_to be_valid
      expect(req.errors[:new_end_time]).to include("must be after new start time")
    end

    it "requires new_start_time to be in the future" do
      req = build(:reschedule_request,
        booking: booking,
        tenant: tenant,
        requested_by: client,
        new_start_time: Time.current - 1.hour,
        new_end_time: Time.current + 1.hour
      )
      expect(req).not_to be_valid
      expect(req.errors[:new_start_time]).to include("must be in the future")
    end

    it "prevents rescheduling to a slot that has an overlapping booking" do
      # Create another paid booking for the same expert
      create(:booking,
        tenant: tenant,
        service: service,
        client: create(:user, :confirmed),
        expert: expert,
        start_time: Time.current + 5.hours,
        end_time: Time.current + 6.hours,
        aasm_state: "paid"
      )

      # Attempt to reschedule first booking into that overlapping window
      req = build(:reschedule_request,
        booking: booking,
        tenant: tenant,
        requested_by: client,
        new_start_time: Time.current + 5.hours + 30.minutes,
        new_end_time: Time.current + 6.hours
      )
      expect(req).not_to be_valid
      expect(req.errors[:base]).to include("Expert has a conflicting booking at this new time")
    end
  end

  describe "#accept!" do
    let(:reschedule_request) do
      create(:reschedule_request,
        booking: booking,
        tenant: tenant,
        requested_by: client,
        new_start_time: Time.current + 10.hours,
        new_end_time: Time.current + 11.hours
      )
    end

    it "updates status and updates the booking schedule" do
      reschedule_request.accept!

      expect(reschedule_request.status).to eq("accepted")
      booking.reload
      expect(booking.start_time.to_i).to eq(reschedule_request.new_start_time.to_i)
      expect(booking.end_time.to_i).to eq(reschedule_request.new_end_time.to_i)
      expect(booking.transitions.last.event).to eq("rescheduled")
    end
  end
end
