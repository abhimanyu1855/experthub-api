# frozen_string_literal: true

class BookingsController < ApplicationController
  # GET /bookings
  def index
    bookings = if current_membership.operator?
                 current_tenant.bookings
               elsif current_membership.expert?
                 current_tenant.bookings.for_expert(current_user.id)
               else
                 current_tenant.bookings.for_client(current_user.id)
               end

    bookings = bookings.upcoming if params[:upcoming] == "true"
    bookings = bookings.past if params[:past] == "true"
    bookings = bookings.includes(:service, :client, :expert, service: [:expert_profile, :category])

    render json: BookingBlueprint.render_as_hash(bookings)
  end

  # GET /bookings/:id
  def show
    booking = current_tenant.bookings.find(params[:id])
    authorize_booking_access!(booking)
    return if performed?

    render json: BookingBlueprint.render_as_hash(booking)
  end

  # POST /bookings
  def create
    service = current_tenant.services.find(booking_params[:service_id])
    
    start_time = Time.zone.parse(booking_params[:start_time]) rescue nil
    end_time = Time.zone.parse(booking_params[:end_time]) rescue nil

    unless start_time && end_time
      return render json: { error: "Invalid start_time or end_time" }, status: :unprocessable_entity
    end

    booking = BookingService.create(
      service: service,
      client: current_user,
      start_time: start_time,
      end_time: end_time,
      tenant: current_tenant
    )

    if booking.payment_initiated?
      if Rails.env.development? && ActiveModel::Type::Boolean.new.cast(params[:mock_payment])
        BookingService.payment_succeeded(
          booking: booking,
          stripe_payment_intent_id: "mock_pi_#{SecureRandom.hex(10)}"
        )
        render json: {
          booking: BookingBlueprint.render_as_hash(booking),
          mock_paid: true
        }, status: :created
      else
        payment_data = payment_payload_for(booking)
        render json: {
          booking: BookingBlueprint.render_as_hash(booking),
          payment: payment_data
        }, status: :created
      end
    else
      render json: BookingBlueprint.render_as_hash(booking), status: :created
    end
  end

  # POST /bookings/:id/confirm
  def confirm
    booking = current_tenant.bookings.find(params[:id])
    
    # Only the assigned expert or an operator of the tenant can confirm
    unless (current_membership.expert? && booking.expert_id == current_user.id) || current_membership.operator?
      return render json: { error: "Not authorized to confirm this booking" }, status: :forbidden
    end

    if booking.may_confirm?
      booking.confirm!
      # Trigger video room creation
      CreateVideoRoomJob.perform_later(booking.id)
      render json: BookingBlueprint.render_as_hash(booking)
    else
      render json: { error: "Booking cannot be confirmed from state: #{booking.aasm_state}" }, status: :unprocessable_entity
    end
  end

  # POST /bookings/:id/cancel
  def cancel
    booking = current_tenant.bookings.find(params[:id])
    authorize_booking_access!(booking)
    return if performed?

    if booking.may_cancel?
      refund_data = process_cancellation_refund(booking)
      booking.cancel!
      booking.refund! if refund_data[:refund_amount_cents].positive? && refund_data[:refund_processed] && booking.may_refund?
      render json: BookingBlueprint.render_as_hash(booking.reload)
    elsif booking.may_request_cancel?
      record_refund_metadata(booking, refund_amount_cents: 0, refund_processed: false, refund_gateway: payment_gateway_for(booking), refund_reason: "cancel_requested")
      booking.request_cancel!
      render json: BookingBlueprint.render_as_hash(booking)
    else
      render json: { error: "Booking cannot be canceled from state: #{booking.aasm_state}" }, status: :unprocessable_entity
    end
  end

  # PATCH/POST /bookings/:id/transcript
  def update_transcript
    booking = current_tenant.bookings.find(params[:id])
    authorize_booking_access!(booking)
    return if performed?

    transcript = transcript_params[:transcript].to_s.strip
    source = transcript_params[:source].presence || "manual"

    return render json: { error: "Transcript can't be blank" }, status: :unprocessable_entity if transcript.blank?
    return render json: { error: "Invalid transcript source" }, status: :unprocessable_entity unless valid_transcript_source?(source)

    metadata = (booking.metadata || {}).merge(
      "transcript" => transcript,
      "transcript_source" => source
    )
    booking.update!(metadata: metadata)

    generate_summary_if_ready(booking, transcript)

    render json: BookingBlueprint.render_as_hash(booking.reload)
  end

  private

  def booking_params
    params.require(:booking).permit(:service_id, :start_time, :end_time)
  end

  def transcript_params
    params.fetch(:booking, params).permit(:transcript, :source)
  end

  def valid_transcript_source?(source)
    %w[manual daily chat].include?(source)
  end

  def generate_summary_if_ready(booking, transcript)
    return unless booking.end_time <= Time.current
    return unless booking.tenant.feature_allowed?(:session_summaries)

    Ai::GenerateSummaryService.summarize(booking: booking, transcript: transcript)
  rescue => e
    Rails.logger.error "Failed to generate AI summary for booking ##{booking.id} after transcript update: #{e.class} - #{e.message}"
  end

  def authorize_booking_access!(booking)
    unless booking.client_id == current_user.id || booking.expert_id == current_user.id || current_membership.operator?
      render json: { error: "Not authorized to access this booking" }, status: :forbidden
    end
  end

  def payment_payload_for(booking)
    if use_razorpay_for?(booking)
      RazorpayService.create_order(booking: booking, tenant: current_tenant).merge(gateway: "razorpay")
    else
      StripeService.create_payment_intent(booking: booking, tenant: current_tenant)
    end
  end

  def use_razorpay_for?(booking)
    razorpay_config = current_tenant.payment_configs.razorpay.active.first
    return false unless razorpay_config

    primary_gateway = current_tenant.payment_configs.active.order(:created_at).first&.gateway
    primary_gateway == "razorpay" || booking.currency.casecmp("INR").zero?
  end

  def process_cancellation_refund(booking)
    refund_amount_cents = cancellation_refund_amount_cents(booking)
    gateway = payment_gateway_for(booking)
    refund_processed = false

    if refund_amount_cents.positive?
      case gateway
      when "stripe"
        StripeService.refund_booking(booking, amount_cents: refund_amount_cents)
        refund_processed = true
      when "razorpay"
        Rails.logger.warn "TODO: Razorpay refund not implemented for booking ##{booking.id}"
      end
    end

    record_refund_metadata(
      booking,
      refund_amount_cents: refund_amount_cents,
      refund_processed: refund_processed,
      refund_gateway: gateway,
      refund_reason: cancellation_policy_for(booking).present? ? "cancellation_policy" : "no_policy"
    )
  end

  def cancellation_refund_amount_cents(booking)
    return 0 unless paid_booking?(booking)

    policy = cancellation_policy_for(booking)
    return 0 unless policy

    if Time.current <= booking.start_time - policy.prior_hours.hours
      booking.client_total_cents
    else
      (booking.client_total_cents * policy.refund_percentage.to_d / 100).round
    end
  end

  def cancellation_policy_for(booking)
    booking.cancellation_policy || booking.service.cancellation_policy || current_tenant.cancellation_policies.active.first
  end

  def paid_booking?(booking)
    booking.payment_records.where(status: "succeeded").exists? ||
      %w[authorized paid confirmed].include?(booking.aasm_state)
  end

  def payment_gateway_for(booking)
    booking.payment_records.where(status: "succeeded").order(:created_at).last&.gateway ||
      (booking.stripe_payment_intent_id.present? ? "stripe" : booking.metadata&.dig("payment_gateway"))
  end

  def record_refund_metadata(booking, refund_amount_cents:, refund_processed:, refund_gateway:, refund_reason:)
    metadata = (booking.metadata || {}).merge(
      "refund_amount_cents" => refund_amount_cents,
      "refund_processed" => refund_processed,
      "refund_gateway" => refund_gateway,
      "refund_reason" => refund_reason
    )
    booking.update!(metadata: metadata)
    {
      refund_amount_cents: refund_amount_cents,
      refund_processed: refund_processed,
      refund_gateway: refund_gateway
    }
  end
end
