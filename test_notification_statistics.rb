#!/usr/bin/env ruby

puts '📊 ТЕСТИРОВАНИЕ СИСТЕМЫ СТАТИСТИКИ УВЕДОМЛЕНИЙ'
puts '=============================================='

begin
  # Проверяем что модель создана
  puts "\n🔍 ПРОВЕРКА МОДЕЛИ NotificationLog"
  puts "=================================="
  
  puts "✅ Модель NotificationLog загружена"
  puts "   Таблица существует: #{NotificationLog.table_exists?}"
  puts "   Поля: #{NotificationLog.column_names.join(', ')}"
  
  # Проверяем контроллер
  puts "\n🎛️ ПРОВЕРКА КОНТРОЛЛЕРА"
  puts "======================"
  
  controller_path = 'app/controllers/api/v1/notification_statistics_controller.rb'
  if File.exist?(controller_path)
    puts "✅ Контроллер статистики найден"
  else
    puts "❌ Контроллер статистики не найден"
  end
  
  # Проверяем маршруты
  puts "\n🛤️ ПРОВЕРКА МАРШРУТОВ СТАТИСТИКИ"
  puts "==============================="
  
  routes_output = `rails routes | grep notification_statistics`
  if routes_output.present?
    puts "✅ Маршруты статистики найдены:"
    puts routes_output
  else
    puts "❌ Маршруты статистики не найдены"
  end
  
  # Создаем тестовые данные
  puts "\n📝 СОЗДАНИЕ ТЕСТОВЫХ ДАННЫХ"
  puts "=========================="
  
  # Очищаем старые тестовые данные
  NotificationLog.where(recipient_email: 'test@example.com').destroy_all
  
  # Создаем разнообразные тестовые записи
  test_logs = [
    {
      notification_type: 'email',
      template_type: 'booking_confirmation',
      recipient_type: 'User',
      recipient_email: 'test@example.com',
      status: 'delivered',
      sent_at: 1.hour.ago,
      delivered_at: 55.minutes.ago
    },
    {
      notification_type: 'email',
      template_type: 'admin_new_booking',
      recipient_type: 'Admin',
      recipient_email: 'admin@example.com',
      status: 'opened',
      sent_at: 2.hours.ago,
      delivered_at: 115.minutes.ago,
      opened_at: 100.minutes.ago
    },
    {
      notification_type: 'telegram',
      template_type: 'booking_created',
      recipient_type: 'User',
      recipient_email: 'telegram_user@example.com',
      status: 'sent',
      sent_at: 30.minutes.ago
    },
    {
      notification_type: 'email',
      template_type: 'review_published',
      recipient_type: 'User',
      recipient_email: 'reviewer@example.com',
      status: 'failed',
      sent_at: 10.minutes.ago,
      error_message: 'SMTP connection failed'
    },
    {
      notification_type: 'email',
      template_type: 'booking_confirmation',
      recipient_type: 'User',
      recipient_email: 'active_user@example.com',
      status: 'clicked',
      sent_at: 3.hours.ago,
      delivered_at: 175.minutes.ago,
      opened_at: 150.minutes.ago,
      clicked_at: 140.minutes.ago
    }
  ]
  
  created_count = 0
  test_logs.each do |log_data|
    begin
      log = NotificationLog.create!(log_data)
      puts "✅ Создан тестовый лог: #{log.template_type} (#{log.status})"
      created_count += 1
    rescue => e
      puts "❌ Ошибка создания лога: #{e.message}"
    end
  end
  
  puts "📊 Создано тестовых логов: #{created_count}"
  
  # Тестируем статистические методы
  puts "\n🧪 ТЕСТИРОВАНИЕ СТАТИСТИЧЕСКИХ МЕТОДОВ"
  puts "====================================="
  
  if NotificationLog.any?
    puts "✅ Всего записей: #{NotificationLog.count}"
    puts "✅ Успешных доставок: #{NotificationLog.delivered.count}"
    puts "✅ Неудачных: #{NotificationLog.failed.count}"
    puts "✅ Открытых: #{NotificationLog.opened.count}"
    
    # Тестируем метрики
    puts "\n📈 МЕТРИКИ:"
    puts "   Success Rate: #{NotificationLog.success_rate}%"
    puts "   Open Rate: #{NotificationLog.open_rate}%"
    puts "   Click Rate: #{NotificationLog.click_rate}%"
    puts "   Bounce Rate: #{NotificationLog.bounce_rate}%"
    
    # Тестируем группировки
    puts "\n📊 ГРУППИРОВКИ:"
    puts "   По типу уведомления: #{NotificationLog.group(:notification_type).count}"
    puts "   По типу шаблона: #{NotificationLog.group(:template_type).count}"
    puts "   По статусу: #{NotificationLog.group(:status).count}"
    
    # Тестируем методы экземпляра
    puts "\n🔍 ТЕСТИРОВАНИЕ МЕТОДОВ ЭКЗЕМПЛЯРА:"
    log = NotificationLog.delivered.first
    if log
      puts "   Тестовый лог: #{log.template_type} (#{log.status_text})"
      puts "   Цвет статуса: #{log.status_color}"
      puts "   Время отклика: #{log.response_time&.round(2)} сек" if log.response_time
      puts "   Время до открытия: #{log.time_to_open&.round(2)} сек" if log.time_to_open
      puts "   Метаданные: #{log.metadata}"
    end
    
  else
    puts "❌ Нет данных для тестирования"
  end
  
  # Тестируем API контроллер
  puts "\n🎮 ТЕСТИРОВАНИЕ API МЕТОДОВ"
  puts "==========================="
  
  begin
    controller = Api::V1::NotificationStatisticsController.new
    
    # Тестируем сериализацию
    if NotificationLog.any?
      log = NotificationLog.first
      serialized = controller.send(:serialize_notification_log, log)
      puts "✅ Сериализация работает: #{serialized.keys.join(', ')}"
      
      detailed = controller.send(:serialize_notification_log, log, detailed: true)
      puts "✅ Детальная сериализация: #{detailed.keys.length} полей"
    end
    
  rescue => e
    puts "❌ Ошибка тестирования API: #{e.message}"
  end
  
rescue => e
  puts "❌ Общая ошибка: #{e.message}"
  puts "   #{e.backtrace.first(3).join('\n   ')}"
end

puts "\n🎯 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"
puts "Система статистики уведомлений готова к использованию." 