# frozen_string_literal: true

# Job for sending booking reminders (2 hours before)
class BookingRemindersJob < ApplicationJob
  queue_as :notifications

  # Отправка напоминаний о записях, которые будут через 2 часа
  def perform
    Rails.logger.info '📅 Запуск BookingRemindersJob - поиск записей на ближайшие 2 часа'

    upcoming_bookings = find_upcoming_bookings
    Rails.logger.info "📧 Найдено #{upcoming_bookings.count} записей для напоминаний"

    upcoming_bookings.each do |booking|
      send_email_reminder(booking)
      send_sms_reminder(booking)
    end

    Rails.logger.info '🎉 BookingRemindersJob завершен'
  end

  private

  def find_upcoming_bookings
    Booking.joins(:service_point)
           .where(booking_date: Date.current)
           .where('start_time BETWEEN ? AND ?', Time.current, Time.current + 2.hours)
           .where(status: %w[pending confirmed])
  end

  def send_email_reminder(booking)
    recipient_email = booking.service_recipient_email || booking.client&.email
    return unless recipient_email.present?

    EmailTemplateMailer.booking_reminder(booking.id, recipient_email).deliver_now
    Rails.logger.info "✅ Email напоминание отправлено на #{recipient_email} для бронирования ##{booking.id}"
  rescue StandardError => e
    Rails.logger.error "❌ Ошибка отправки email для бронирования ##{booking.id}: #{e.message}"
  end

  def send_sms_reminder(booking)
    phone = booking.service_recipient_phone || booking.client&.phone
    return unless phone.present?

    result = SmsService.send_booking_reminder(phone, booking)
    if result[:success]
      Rails.logger.info "✅ SMS напоминание отправлено на #{SmsService.send(:mask_phone, phone)} для бронирования ##{booking.id}"
    else
      Rails.logger.warn "⚠️ SMS не отправлено для бронирования ##{booking.id}: #{result[:error]}"
    end
  rescue StandardError => e
    Rails.logger.error "❌ Ошибка отправки SMS для бронирования ##{booking.id}: #{e.message}"
  end
end 