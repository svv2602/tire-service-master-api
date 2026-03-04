# frozen_string_literal: true

# Job for sending booking reminders before scheduled appointments.
# Supports configurable reminder window (default: 2 hours before).
# Respects NotificationChannelSettings for SMS on/off per channel.
class BookingRemindersJob < ApplicationJob
  queue_as :notifications

  # Default reminder window in hours (can be overridden per call)
  DEFAULT_REMINDER_HOURS = 2

  # @param reminder_hours [Integer, nil] hours before booking to send reminder
  def perform(reminder_hours = nil)
    hours = (reminder_hours || DEFAULT_REMINDER_HOURS).to_i
    Rails.logger.info "[BookingRemindersJob] Starting - searching bookings within #{hours} hours"

    upcoming_bookings = find_upcoming_bookings(hours)
    Rails.logger.info "[BookingRemindersJob] Found #{upcoming_bookings.count} bookings for reminders"

    upcoming_bookings.each do |booking|
      send_email_reminder(booking)
      send_sms_reminder(booking) if sms_channel_enabled?
    end

    Rails.logger.info '[BookingRemindersJob] Completed'
  end

  private

  def find_upcoming_bookings(hours)
    Booking.joins(:service_point)
           .includes(:service_point, client: :user)
           .where(booking_date: Date.current)
           .where('start_time BETWEEN ? AND ?', Time.current, Time.current + hours.hours)
           .where(status: %w[pending confirmed])
  end

  def send_email_reminder(booking)
    recipient_email = booking.service_recipient_email || booking.client&.user&.email
    return unless recipient_email.present?

    EmailTemplateMailer.booking_reminder(booking.id, recipient_email).deliver_now
    Rails.logger.info "[BookingRemindersJob] Email reminder sent to #{recipient_email} for booking ##{booking.id}"
  rescue StandardError => e
    Rails.logger.error "[BookingRemindersJob] Email error for booking ##{booking.id}: #{e.message}"
  end

  def send_sms_reminder(booking)
    phone = booking.service_recipient_phone || booking.client&.user&.phone
    return unless phone.present?

    result = SmsService.send_booking_reminder(phone, booking)
    if result[:success]
      Rails.logger.info "[BookingRemindersJob] SMS reminder sent to #{SmsService.send(:mask_phone, phone)} for booking ##{booking.id}"
    else
      Rails.logger.warn "[BookingRemindersJob] SMS not sent for booking ##{booking.id}: #{result[:error]}"
    end
  rescue StandardError => e
    Rails.logger.error "[BookingRemindersJob] SMS error for booking ##{booking.id}: #{e.message}"
  end

  # Check if SMS notification channel is enabled in settings
  def sms_channel_enabled?
    sms_setting = NotificationChannelSetting.find_by(channel_type: 'sms')
    # If no setting exists, default to enabled
    sms_setting.nil? || sms_setting.enabled?
  end
end
