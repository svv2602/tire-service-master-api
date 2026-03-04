# frozen_string_literal: true

# Service responsible for deciding whether a booking should be auto-confirmed.
#
# Decision tree:
#   1. Booking already confirmed        -> skip (no action)
#   2. Created by admin/partner          -> confirm immediately
#   3. ServicePoint auto_confirm_enabled -> check delay
#     3a. delay > 0                      -> schedule AutoConfirmBookingJob
#     3b. delay == 0                     -> confirm immediately
#   4. Category has auto_confirmation    -> confirm immediately
#   5. Otherwise                         -> keep pending
#
# Usage:
#   result = BookingConfirmationService.call(booking)
#   result.success?   # => true
#   result.decision    # => :confirmed / :scheduled / :pending / :skipped
#   result.reason      # => human-readable explanation
class BookingConfirmationService < ApplicationService
  # Result structure for confirmation decision
  Result = Struct.new(:success, :decision, :reason, :error, keyword_init: true) do
    def success?
      success
    end

    def confirmed?
      decision == :confirmed
    end

    def scheduled?
      decision == :scheduled
    end

    def pending?
      decision == :pending
    end

    def skipped?
      decision == :skipped
    end
  end

  # @param booking [Booking] the booking to evaluate
  def initialize(booking)
    @booking = booking
    @service_point = booking.service_point
  end

  # Execute the confirmation decision tree
  # @return [Result]
  def call
    log_info "Evaluating auto-confirmation for booking #{@booking.id}"

    # 1. Already confirmed — skip
    if @booking.status == 'confirmed'
      return build_result(:skipped, 'booking_already_confirmed')
    end

    # 2. Admin/partner booking — confirm immediately
    if admin_or_partner_booking?
      return confirm_immediately!('admin_or_partner_booking')
    end

    # 3. Service point global auto-confirm enabled
    if @service_point.auto_confirm_enabled?
      delay_minutes = @service_point.auto_confirm_delay_minutes

      if delay_minutes.positive?
        return schedule_delayed_confirmation!(delay_minutes)
      else
        return confirm_immediately!('service_point_auto_confirm_enabled')
      end
    end

    # 4. Category-level auto-confirmation
    if category_auto_confirmation_enabled?
      return confirm_immediately!('category_auto_confirmation_enabled')
    end

    # 5. Default — keep pending
    build_result(:pending, 'auto_confirm_disabled')
  rescue StandardError => e
    log_error "Error evaluating auto-confirmation for booking #{@booking.id}: #{e.message}"
    log_error e.backtrace&.first(5)&.join("\n")
    Result.new(success: false, decision: :error, reason: 'unexpected_error', error: e.message)
  end

  private

  # Check if the booking was created by an admin or partner user
  # @return [Boolean]
  def admin_or_partner_booking?
    user = @booking.client&.user
    return false unless user

    user.admin? || user.partner?
  end

  # Check if auto-confirmation is enabled for the booking's service category
  # @return [Boolean]
  def category_auto_confirmation_enabled?
    return false unless @booking.service_category_id.present?

    @service_point.auto_confirmation_enabled_for_category?(@booking.service_category_id)
  end

  # Confirm the booking immediately by updating status column directly
  # Also sends confirmation SMS if enabled on the service point
  # @param reason [String] reason for confirmation
  # @return [Result]
  def confirm_immediately!(reason)
    # Use update_column to avoid triggering callbacks (prevent infinite loops)
    @booking.update_column(:status, 'confirmed')

    log_info "Booking #{@booking.id} confirmed immediately: #{reason}"

    # Send SMS if enabled
    send_confirmation_sms if @service_point.send_confirmation_sms_enabled?

    build_result(:confirmed, reason)
  end

  # Schedule a delayed confirmation via AutoConfirmBookingJob
  # @param delay_minutes [Integer] delay in minutes
  # @return [Result]
  def schedule_delayed_confirmation!(delay_minutes)
    @service_point.schedule_auto_confirm(@booking)

    log_info "Booking #{@booking.id} scheduled for confirmation in #{delay_minutes} minutes"

    build_result(:scheduled, "delayed_confirmation_#{delay_minutes}_minutes")
  end

  # Send booking confirmation SMS to the service recipient
  def send_confirmation_sms
    return unless @booking.service_recipient_phone.present?

    begin
      SmsService.send_booking_confirmation(@booking.service_recipient_phone, @booking)
      log_info "Confirmation SMS sent to #{@booking.service_recipient_phone} for booking #{@booking.id}"
    rescue StandardError => e
      log_error "Failed to send confirmation SMS for booking #{@booking.id}: #{e.message}"
    end
  end

  # Build a successful result
  # @param decision [Symbol] :confirmed, :scheduled, :pending, :skipped
  # @param reason [String] human-readable reason
  # @return [Result]
  def build_result(decision, reason)
    log_info "BookingConfirmation: booking=#{@booking.id}, decision=#{decision}, reason=#{reason}"

    Result.new(success: true, decision: decision, reason: reason)
  end
end
