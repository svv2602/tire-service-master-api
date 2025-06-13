class DailyRemindersJob < ApplicationJob
  queue_as :notifications

  # Отправка ежедневных напоминаний о записях на завтра
  def perform(date = Date.current)
    # Используем сервис уведомлений для отправки напоминаний
    NotificationService.send_daily_reminders
  end
end 