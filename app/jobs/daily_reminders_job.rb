# frozen_string_literal: true

# Job for sending daily reminders (day before booking)
class DailyRemindersJob < ApplicationJob
  queue_as :notifications

  # Отправка ежедневных напоминаний о записях на завтра
  def perform(date = Date.current)
    tomorrow = date + 1.day
    Rails.logger.info "📅 Запуск DailyRemindersJob - поиск записей на #{tomorrow.strftime('%d.%m.%Y')}"

    tomorrow_bookings = find_tomorrow_bookings(tomorrow)
    Rails.logger.info "📧 Найдено #{tomorrow_bookings.count} записей на завтра"

    tomorrow_bookings.each do |booking|
      send_email_reminder(booking)
      send_sms_reminder(booking)
    end

    Rails.logger.info '🎉 DailyRemindersJob завершен'
  end

  private

  def find_tomorrow_bookings(tomorrow)
    Booking.joins(:service_point)
           .where(booking_date: tomorrow)
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
      Rails.logger.info "✅ SMS напоминание отправлено для бронирования ##{booking.id}"
    else
      Rails.logger.warn "⚠️ SMS не отправлено для бронирования ##{booking.id}: #{result[:error]}"
    end
  rescue StandardError => e
    Rails.logger.error "❌ Ошибка отправки SMS для бронирования ##{booking.id}: #{e.message}"
  end
end 