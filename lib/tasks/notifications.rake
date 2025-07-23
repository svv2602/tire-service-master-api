namespace :notifications do
  desc "Генерация тестовых данных для демонстрации статистики уведомлений"
  task generate_test_data: :environment do
    puts "🚀 Генерация тестовых данных уведомлений..."
    
    # Находим пользователей для тестов
    users = User.limit(5)
    if users.empty?
      puts "❌ Не найдено пользователей для тестирования"
      exit
    end
    
    # Тестовые данные
    test_emails = ['test1@example.com', 'test2@example.com', 'test3@example.com', 'client@test.com', 'admin@test.com']
    test_templates = ['booking_confirmation', 'booking_reminder', 'user_welcome', 'booking_cancelled']
    test_messages = [
      'Ваше бронирование подтверждено',
      'Напоминание о предстоящей записи',
      'Добро пожаловать в систему',
      'Бронирование отменено'
    ]
    
    # Генерируем тестовые notification_logs за последние 30 дней
    puts "📧 Создание email notification logs..."
    30.times do |i|
      date = i.days.ago
      
      # Email уведомления
      rand(3..8).times do
        NotificationLog.create!(
          notification_type: 'email',
          recipient_type: 'User',
          recipient_id: users.sample.id,
          recipient_email: test_emails.sample,
          template_type: test_templates.sample,
          status: ['sent', 'delivered', 'opened', 'failed'].sample,
          sent_at: date + rand(0..23).hours + rand(0..59).minutes,
          delivered_at: rand > 0.1 ? date + rand(1..5).hours : nil,
          metadata: { source: 'test_data' }
        )
      end
      
      # Push уведомления
      rand(2..5).times do
        NotificationLog.create!(
          notification_type: 'push',
          recipient_type: 'User',
          recipient_id: users.sample.id,
          template_type: test_templates.sample,
          status: ['sent', 'delivered', 'clicked', 'failed'].sample,
          sent_at: date + rand(0..23).hours + rand(0..59).minutes,
          delivered_at: rand > 0.15 ? date + rand(1..3).hours : nil,
          metadata: { source: 'test_data' }
        )
      end
      
      # Telegram уведомления
      rand(1..4).times do
        NotificationLog.create!(
          notification_type: 'telegram',
          recipient_type: 'User',
          recipient_id: users.sample.id,
          template_type: test_templates.sample,
          status: ['sent', 'delivered', 'opened', 'failed'].sample,
          sent_at: date + rand(0..23).hours + rand(0..59).minutes,
          delivered_at: rand > 0.05 ? date + rand(1..2).hours : nil,
          metadata: { source: 'test_data' }
        )
      end
    end
    
    # Создаем TelegramNotification записи
    puts "📱 Создание Telegram notifications..."
    users.each do |user|
      rand(2..5).times do
        TelegramNotification.create!(
          user: user,
          chat_id: rand(100000000..999999999).to_s,
          message: test_messages.sample,
          notification_type: ['booking', 'general', 'reminder'].sample,
          status: ['sent', 'failed'].sample,
          sent_at: rand(30.days.ago..Time.current)
        )
      end
    end
    
    # Создаем Notification записи
    puts "🔔 Создание notifications..."
    notification_types = NotificationType.all
    if notification_types.any?
      users.each do |user|
        rand(3..7).times do
          Notification.create!(
            notification_type: notification_types.sample,
            recipient_type: 'User',
            recipient_id: user.id,
            title: "Уведомление #{rand(1..100)}",
            message: test_messages.sample,
            send_via: ['email', 'push', 'telegram'].sample,
            sent_at: rand > 0.2 ? rand(30.days.ago..Time.current) : nil,
            is_read: rand > 0.3,
            priority: ['normal', 'high', 'low'].sample,
            category: ['booking', 'general', 'system', 'promotion'].sample
          )
        end
      end
    end
    
    puts "✅ Тестовые данные успешно созданы!"
    puts "📊 Статистика:"
    puts "  - NotificationLog записей: #{NotificationLog.count}"
    puts "  - TelegramNotification записей: #{TelegramNotification.count}"
    puts "  - Notification записей: #{Notification.count}"
    puts ""
    puts "🎯 Теперь можно проверить статистику на странице /admin/notifications/channels"
  end
  
  desc "Очистка тестовых данных уведомлений"
  task cleanup_test_data: :environment do
    puts "🧹 Очистка тестовых данных..."
    
    NotificationLog.where("metadata->>'source' = 'test_data'").delete_all
    TelegramNotification.where(created_at: 30.days.ago..Time.current).delete_all
    Notification.where(created_at: 30.days.ago..Time.current).delete_all
    
    puts "✅ Тестовые данные очищены!"
  end
end 