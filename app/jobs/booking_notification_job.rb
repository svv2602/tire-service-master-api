class BookingNotificationJob < ApplicationJob
  queue_as :notifications

  # Отправка уведомления о бронировании
  def perform(booking_id, notification_type)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    # Используем сервис уведомлений для отправки
    NotificationService.send_booking_notification(booking, notification_type)
  end
end 