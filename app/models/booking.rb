# frozen_string_literal: true

# Booking — the core transaction model
# Ported from mytin: Transaction (38 states) + Booking + ScheduledTransaction
# Simplified to 15 states. See implementation_plan.md for full mapping.
#
# Commission engine ported from transaction.rb L605-640:
#   seller_commission = max(subtotal * rate, minimum_commission)
#   buyer_fee = subtotal * buyer_commission_pct
#   expert_payout = subtotal - seller_commission
class Booking < ApplicationRecord
  include AASM

  # --- Associations ---
  belongs_to :service
  belongs_to :tenant
  belongs_to :client, class_name: "User"
  belongs_to :expert, class_name: "User"

  has_many :transitions, class_name: "BookingTransition", dependent: :destroy
  has_many :payment_records, dependent: :destroy
  has_one  :video_room, dependent: :destroy
  belongs_to :cancellation_policy, optional: true
  has_one  :session_summary, dependent: :destroy
  has_many :reschedule_requests, dependent: :destroy

  # --- Validations ---
  validates :start_time, :end_time, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validate  :end_time_after_start_time
  validate  :no_overlapping_bookings, on: :create

  # --- Video Room Delegation helper methods ---
  def video_room_url
    video_room&.url
  end

  def video_room_provider
    video_room&.provider
  end

  def video_room_id
    video_room&.provider_room_id
  end

  # --- Scopes ---
  scope :upcoming, -> { where("start_time > ?", Time.current).order(:start_time) }
  scope :past, -> { where("end_time < ?", Time.current).order(start_time: :desc) }
  scope :for_expert, ->(user_id) { where(expert_id: user_id) }
  scope :for_client, ->(user_id) { where(client_id: user_id) }
  scope :confirmed_or_paid, -> { where(aasm_state: %w[paid confirmed confirmed_free]) }

  # --- State Machine (15 states, from mytin's 38) ---
  aasm do
    state :pending, initial: true
    state :payment_initiated
    state :payment_action_required
    state :payment_failed
    state :payment_expired
    state :authorized
    state :paid
    state :confirmed
    state :confirmed_free
    state :rejected
    state :canceled
    state :cancel_requested
    state :refunded
    state :errored

    # Free booking flow
    event :confirm_free do
      transitions from: :pending, to: :confirmed_free
    end

    # Paid booking flow
    event :initiate_payment do
      transitions from: :pending, to: :payment_initiated
    end

    event :require_action do
      transitions from: :payment_initiated, to: :payment_action_required
    end

    event :authorize_payment do
      transitions from: [:payment_initiated, :payment_action_required], to: :authorized
    end

    event :mark_paid, after: :after_payment do
      transitions from: :authorized, to: :paid
    end

    event :confirm, after: :after_confirmation do
      transitions from: :paid, to: :confirmed
    end

    event :reject do
      transitions from: [:authorized, :paid], to: :rejected
    end

    event :cancel do
      transitions from: [:pending, :authorized, :paid, :confirmed, :confirmed_free], to: :canceled
    end

    event :request_cancel do
      transitions from: [:paid, :confirmed], to: :cancel_requested
    end

    event :approve_cancel do
      transitions from: :cancel_requested, to: :canceled
    end

    event :reject_cancel do
      transitions from: :cancel_requested, to: :paid
    end

    event :refund do
      transitions from: [:paid, :confirmed, :canceled], to: :refunded
    end

    event :fail_payment do
      transitions from: [:payment_initiated, :payment_action_required], to: :payment_failed
    end

    event :expire_payment do
      transitions from: :payment_action_required, to: :payment_expired
    end

    event :mark_error do
      transitions from: [:payment_initiated, :authorized], to: :errored
    end
  end

  # --- Callbacks ---
  before_create :calculate_commission

  # --- Commission (from mytin transaction.rb L605-640) ---
  def calculate_commission
    result = CommissionCalculator.calculate(self)
    self.commission_cents = result[:commission_cents]
    self.buyer_fee_cents = result[:buyer_fee_cents]
    self.expert_payout_cents = result[:expert_payout_cents]
  end

  # Total the client pays (price + buyer fee - discount)
  def client_total_cents
    price_cents + buyer_fee_cents - discount_cents
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end

  # Overlap detection — ported from mytin's booking overlap logic
  # Checks existing confirmed/paid bookings for the same expert at overlapping times
  def no_overlapping_bookings
    return unless expert_id && start_time && end_time

    overlapping = Booking.where(expert_id: expert_id)
                         .where.not(id: id)
                         .confirmed_or_paid
                         .where("start_time < ? AND end_time > ?", end_time, start_time)

    errors.add(:base, "Expert has a conflicting booking at this time") if overlapping.exists?
  end

  def after_payment
    # Schedule auto-confirmation (from mytin ConfirmConversation)
    update!(auto_confirm_at: end_time + 2.days)
    # Jobs will be enqueued by BookingService
  end

  def after_confirmation
    # Mark booking as confirmed — jobs enqueued by BookingService
  end
end
