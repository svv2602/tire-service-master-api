class BookingNotificationJob < ApplicationJob
  queue_as :notifications

  # Отправка уведомления о бронировании
  def perform(booking_id, notification_type)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    Rails.logger.info "📧 BookingNotificationJob: booking_id=#{booking_id}, type=#{notification_type}"

    # Определяем email получателя
    recipient_email = booking.service_recipient_email || booking.client&.email
    return unless recipient_email.present?

    # Отправляем уведомление через EmailTemplateMailer в зависимости от типа
    case notification_type.to_s
    when 'booking_created'
      EmailTemplateMailer.booking_confirmation(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано подтверждение создания бронирования на #{recipient_email}"
    when 'booking_confirmed'
      EmailTemplateMailer.booking_confirmation(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано подтверждение бронирования на #{recipient_email}"
    when 'booking_cancelled'
      EmailTemplateMailer.booking_cancelled(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано уведомление об отмене на #{recipient_email}"
    when 'booking_completed'
      # Отправляем два уведомления: о завершении и запрос отзыва
      EmailTemplateMailer.service_completed(booking_id, recipient_email).deliver_later
      EmailTemplateMailer.review_request(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланированы уведомления о завершении и запрос отзыва на #{recipient_email}"
    when 'booking_time_changed'
      EmailTemplateMailer.booking_time_changed(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано уведомление об изменении времени на #{recipient_email}"
    when 'booking_location_changed'
      EmailTemplateMailer.booking_location_changed(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано уведомление об изменении сервисной точки на #{recipient_email}"
    when 'booking_client_info_changed'
      EmailTemplateMailer.booking_client_info_changed(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано уведомление об изменении данных клиента на #{recipient_email}"
    else
      Rails.logger.warn "⚠️ Неизвестный тип уведомления: #{notification_type}"
    end

  rescue => e
    Rails.logger.error "❌ Ошибка в BookingNotificationJob: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end 