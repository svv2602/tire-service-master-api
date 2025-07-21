class DailyRemindersJob < ApplicationJob
  queue_as :notifications

  # Отправка ежедневных напоминаний о записях на завтра
  def perform(date = Date.current)
    tomorrow = date + 1.day
    Rails.logger.info "📅 Запуск DailyRemindersJob - поиск записей на #{tomorrow.strftime('%d.%m.%Y')}"
    
    # Находим бронирования на завтра
    tomorrow_bookings = Booking.joins(:service_point)
                              .where(booking_date: tomorrow)
                              .where(status: ['pending', 'confirmed'])

    Rails.logger.info "📧 Найдено #{tomorrow_bookings.count} записей на завтра"

    tomorrow_bookings.each do |booking|
      recipient_email = booking.service_recipient_email || booking.client&.email
      next unless recipient_email.present?

      begin
        EmailTemplateMailer.booking_reminder(booking.id, recipient_email).deliver_now
        Rails.logger.info "✅ Отправлено ежедневное напоминание на #{recipient_email} для бронирования ##{booking.id}"
      rescue => e
        Rails.logger.error "❌ Ошибка отправки ежедневного напоминания для бронирования ##{booking.id}: #{e.message}"
      end
    end

    Rails.logger.info "🎉 DailyRemindersJob завершен"
  end
end 