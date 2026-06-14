# frozen_string_literal: true

# Ported from mytin: listing.rb L692-820 (get_date_time_slots)
# The most complex business logic in the codebase — 130 lines of nested timezone
# arithmetic, booking overlap detection, Google Calendar integration, and
# multi-joinee slot filtering.
#
# ExpertHub: Clean reimplementation with clear separation of concerns.
class AvailabilityService
  # Returns available time slots for a service on a given date
  #
  # @param service [Service]
  # @param date [Date]
  # @param timezone_offset [Integer] client timezone offset in minutes from UTC
  # @return [Array<Hash>] available slots with :start_time, :end_time, :available
  def self.available_slots(service:, date:, timezone_offset: 0)
    new(service: service, date: date, timezone_offset: timezone_offset).call
  end

  def initialize(service:, date:, timezone_offset:)
    @service = service
    @expert_profile = service.expert_profile
    @date = date
    @timezone_offset = timezone_offset
  end

  def call
    return [] if blocked_date?

    working_slots = working_hours_for_day
    return [] if working_slots.empty?

    all_slots = generate_time_slots(working_slots)
    existing_bookings = booked_slots_for_date
    buffer_minutes = @service.booking_buffer_minutes

    all_slots.map do |slot|
      available = slot_available?(slot, existing_bookings, buffer_minutes)
      {
        start_time: slot[:start],
        end_time: slot[:end],
        available: available
      }
    end
  end

  private

  def blocked_date?
    @service.blocked_dates.exists?(blocked_on: @date)
  end

  # Get working hours for this day of the week
  # mytin equivalent: listing.working_hours_for(day)
  def working_hours_for_day
    iso_day = @date.cwday  # 1=Mon .. 7=Sun
    @expert_profile.working_time_slots.for_day(iso_day)
  end

  # Generate fixed-interval time slots from working hours
  # mytin equivalent: listing.rb L710-760 (nested loops with slot_interval)
  def generate_time_slots(working_slots)
    duration = @service.duration_minutes
    interval = @service.slot_interval_minutes
    slots = []

    working_slots.each do |ws|
      from = parse_time(ws.from_time)
      till = parse_time(ws.till_time)

      cursor = from
      while cursor + duration.minutes <= till
        slot_start = @date.in_time_zone.change(hour: cursor.hour, min: cursor.min)
        slot_end = slot_start + duration.minutes

        slots << { start: slot_start, end: slot_end }
        cursor += interval.minutes
      end
    end

    slots
  end

  # Check if a slot overlaps with any existing booking
  # mytin equivalent: listing.rb L780-810 (overlap detection loop)
  def slot_available?(slot, existing_bookings, buffer_minutes)
    # Don't show past slots
    return false if slot[:start] < Time.current

    # Buffer: slot must start at least N minutes from now
    return false if buffer_minutes > 0 && slot[:start] < Time.current + buffer_minutes.minutes

    # Overlap check
    existing_bookings.none? do |booking|
      slot[:start] < booking[:end] && slot[:end] > booking[:start]
    end
  end

  # Get all confirmed/paid bookings for this expert on this date
  def booked_slots_for_date
    start_of_day = @date.in_time_zone.beginning_of_day
    end_of_day = @date.in_time_zone.end_of_day

    Booking.where(expert_id: @expert_profile.user_id)
           .confirmed_or_paid
           .where("start_time < ? AND end_time > ?", end_of_day, start_of_day)
           .pluck(:start_time, :end_time)
           .map { |s, e| { start: s, end: e } }
  end

  def parse_time(time_string)
    Time.parse(time_string)
  end
end
