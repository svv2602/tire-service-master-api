# frozen_string_literal: true

# Background job for auto-confirming bookings based on service point automation settings.
# Scheduled by BookingConfirmationService when a booking requires delayed confirmation.
#
# This job handles the delayed confirmation path:
#   1. Verifies booking is still pending
#   2. Verifies auto-confirm is still enabled on the service point
#   3. Checks additional conditions (working hours, advance booking, categories)
#   4. Confirms the booking if all conditions are met
#   5. Optionally auto-assigns an operator and sends confirmation SMS
class AutoConfirmBookingJob < ApplicationJob
  queue_as :default

  # Retry configuration
  retry_on ActiveRecord::RecordNotFound, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError

  # @param booking_id [Integer] ID of the booking to auto-confirm
  def perform(booking_id)
    booking = Booking.find(booking_id)

    # Skip if booking is no longer in pending status
    unless booking.pending?
      Rails.logger.info "[AutoConfirmBookingJob] Booking #{booking_id} is not pending (status: #{booking.status}), skipping"
      return
    end

    service_point = booking.service_point
    settings = AutomationSettingsAccessor.new(service_point)

    # Verify auto-confirmation is still enabled
    unless settings.auto_confirm_enabled?
      Rails.logger.info "[AutoConfirmBookingJob] Auto-confirm disabled for service point #{service_point.id}, skipping"
      return
    end

    # Check conditions
    unless conditions_met?(booking, settings)
      Rails.logger.info "[AutoConfirmBookingJob] Conditions not met for booking #{booking_id}, skipping"
      return
    end

    # Perform auto-confirmation
    ActiveRecord::Base.transaction do
      booking.confirm!

      # Auto-assign operator if enabled
      auto_assign_operator(booking, service_point, settings) if settings.auto_assign_operator?

      # Send confirmation SMS if enabled
      send_confirmation_sms(booking, settings) if settings.send_confirmation_sms?

      Rails.logger.info "[AutoConfirmBookingJob] Booking #{booking_id} auto-confirmed successfully"
    end
  rescue AASM::InvalidTransition => e
    Rails.logger.warn "[AutoConfirmBookingJob] Cannot transition booking #{booking_id}: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[AutoConfirmBookingJob] Error auto-confirming booking #{booking_id}: #{e.message}"
    raise
  end

  private

  # Check if auto-confirm conditions are met
  def conditions_met?(booking, settings)
    conditions = settings.auto_confirm_conditions

    # If no conditions specified, allow all
    return true if conditions.blank?

    # Check time window condition
    if conditions['within_working_hours']
      return false unless within_working_hours?(booking)
    end

    # Check advance booking condition (e.g., booking made at least X hours in advance)
    if conditions['min_advance_hours'].present?
      min_hours = conditions['min_advance_hours'].to_i
      booking_datetime = booking.booking_date.to_datetime + booking.start_time.seconds_since_midnight.seconds
      return false if booking_datetime < Time.current + min_hours.hours
    end

    # Check max advance booking condition
    if conditions['max_advance_days'].present?
      max_days = conditions['max_advance_days'].to_i
      return false if booking.booking_date > Date.current + max_days.days
    end

    # Check category condition
    if conditions['categories'].present?
      allowed_categories = Array(conditions['categories']).map(&:to_i)
      return false unless allowed_categories.include?(booking.service_category_id.to_i)
    end

    true
  end

  # Check if booking is within working hours
  def within_working_hours?(booking)
    service_point = booking.service_point
    booking_time = booking.start_time

    # Get working hours for the booking date's day of week
    day_name = booking.booking_date.strftime('%A').downcase
    working_hours = service_point.working_hours&.dig(day_name)

    return false unless working_hours && working_hours['is_working_day']

    start_hour = Time.parse(working_hours['start'])
    end_hour = Time.parse(working_hours['end'])
    booking_hour = Time.parse(booking_time.strftime('%H:%M'))

    booking_hour >= start_hour && booking_hour < end_hour
  rescue StandardError
    true # Default to allowing if we can't parse hours
  end

  # Auto-assign an operator to the booking
  def auto_assign_operator(booking, service_point, settings)
    # Find available operator for the booking's date and time
    available_operator = find_available_operator(service_point, booking)

    return unless available_operator

    # Assign operator (if booking has operator_id field)
    if booking.respond_to?(:operator_id=)
      booking.update(operator_id: available_operator.id)
      Rails.logger.info "[AutoConfirmBookingJob] Assigned operator #{available_operator.id} to booking #{booking.id}"
    end
  end

  # Find available operator for booking slot
  def find_available_operator(service_point, booking)
    # Get active operators for this service point
    operators = service_point.active_operators

    return nil if operators.empty?

    # Check operator schedules for the booking date
    booking_date = booking.booking_date
    booking_start = booking.start_time

    scheduled_operators = OperatorSchedule.where(
      service_point_id: service_point.id,
      schedule_date: booking_date,
      operator_id: operators.pluck(:id)
    ).select do |schedule|
      schedule.start_time <= booking_start && schedule.end_time >= booking_start
    end.map(&:operator)

    # Return first available operator or any active operator if no schedules
    scheduled_operators.first || operators.first
  end

  # Send confirmation SMS to client
  def send_confirmation_sms(booking, settings)
    phone = booking.service_recipient_phone
    return unless phone.present?

    begin
      SmsService.send_booking_confirmation(phone, booking)
      Rails.logger.info "[AutoConfirmBookingJob] Sent confirmation SMS to #{phone} for booking #{booking.id}"
    rescue StandardError => e
      Rails.logger.error "[AutoConfirmBookingJob] Failed to send SMS: #{e.message}"
      # Don't raise - SMS failure shouldn't fail the auto-confirm
    end
  end
end

# Helper class to access automation settings with defaults
class AutomationSettingsAccessor
  DEFAULT_DELAY_MINUTES = 0

  def initialize(service_point)
    @settings = service_point.automation_settings || {}
  end

  def auto_confirm_enabled?
    @settings['auto_confirm_enabled'] == true
  end

  def auto_confirm_delay_minutes
    @settings['auto_confirm_delay_minutes'].to_i || DEFAULT_DELAY_MINUTES
  end

  def auto_assign_operator?
    @settings['auto_assign_operator'] == true
  end

  def send_confirmation_sms?
    @settings['send_confirmation_sms'] == true
  end

  def auto_confirm_conditions
    @settings['auto_confirm_conditions'] || {}
  end
end
