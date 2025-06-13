class BookingRemindersJob < ApplicationJob
  queue_as :notifications

  # Отправка напоминаний о записях, которые будут через 2 часа
  def perform
    # Используем сервис уведомлений для отправки напоминаний
    NotificationService.send_booking_reminders
  end
end 