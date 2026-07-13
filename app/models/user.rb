# frozen_string_literal: true

# User model — split from mytin's Person (6,336 LOC → ~50 LOC)
# Contains ONLY auth + basic profile. Expert-specific data is in ExpertProfile.
class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable, :confirmable, :lockable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  # --- Associations ---
  has_many :memberships, dependent: :destroy
  has_many :tenants, through: :memberships
  has_one  :expert_profile, dependent: :destroy
  has_one_attached :avatar

  has_many :client_bookings,  class_name: "Booking", foreign_key: :client_id
  has_many :expert_bookings,  class_name: "Booking", foreign_key: :expert_id
  has_many :reviews_given, class_name: "Review", foreign_key: :reviewer_id, dependent: :destroy
  has_many :reviews_received, class_name: "Review", foreign_key: :reviewee_id, dependent: :destroy
  has_many :reschedule_requests, foreign_key: :requested_by_id, dependent: :destroy
  has_many :conversation_participations, dependent: :destroy
  has_many :conversations, through: :conversation_participations
  has_many :messages, foreign_key: :sender_id, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :courses_enrolled, through: :enrollments, source: :course
  has_many :attendances, class_name: "SessionAttendance", dependent: :destroy
  has_many :group_sessions, through: :attendances
  has_many :package_purchases, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :referral_credits, dependent: :destroy
  has_many :expert_applications, dependent: :destroy

  # --- Validations ---
  validates :given_name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :referral_code, uniqueness: true, allow_nil: true

  before_create :generate_referral_code

  # --- Methods ---
  def displayed_name
    display_name.presence || [given_name, family_name].compact.join(" ")
  end

  def role_in(tenant)
    memberships.find_by(tenant: tenant)&.role
  end

  def operator_of?(tenant)
    role_in(tenant) == "operator"
  end

  def expert_in?(tenant)
    role_in(tenant) == "expert"
  end

  def client_in?(tenant)
    role_in(tenant) == "client"
  end

  # Returns whether the user has an avatar attached
  def has_avatar?
    avatar.attached?
  end

  # JWT payload
  def jwt_payload
    {
      "sub" => id.to_s,
      "jti" => jti,
      "user_id" => id,
      "email" => email,
      "name" => displayed_name
    }
  end

  private

  def generate_referral_code
    loop do
      self.referral_code = "EH-#{SecureRandom.alphanumeric(6).upcase}"
      break unless User.exists?(referral_code: referral_code)
    end
  end
end

