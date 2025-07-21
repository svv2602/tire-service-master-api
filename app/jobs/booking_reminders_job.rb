class BookingRemindersJob < ApplicationJob
  queue_as :notifications

  # Отправка напоминаний о записях, которые будут через 2 часа
  def perform
    Rails.logger.info "📅 Запуск BookingRemindersJob - поиск записей на ближайшие 2 часа"
    
    # Находим бронирования на следующие 2 часа
    upcoming_bookings = Booking.joins(:service_point)
                              .where(booking_date: Date.current)
                              .where('start_time BETWEEN ? AND ?', 
                                     Time.current, 
                                     Time.current + 2.hours)
                              .where(status: ['pending', 'confirmed'])

    Rails.logger.info "📧 Найдено #{upcoming_bookings.count} записей для напоминаний"

    upcoming_bookings.each do |booking|
      recipient_email = booking.service_recipient_email || booking.client&.email
      next unless recipient_email.present?

      begin
        EmailTemplateMailer.booking_reminder(booking.id, recipient_email).deliver_now
        Rails.logger.info "✅ Отправлено напоминание на #{recipient_email} для бронирования ##{booking.id}"
      rescue => e
        Rails.logger.error "❌ Ошибка отправки напоминания для бронирования ##{booking.id}: #{e.message}"
      end
    end

    Rails.logger.info "🎉 BookingRemindersJob завершен"
  end
end 