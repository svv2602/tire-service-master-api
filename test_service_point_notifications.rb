#!/usr/bin/env ruby

puts '🏢 ТЕСТИРОВАНИЕ УВЕДОМЛЕНИЙ О СЕРВИСНЫХ ТОЧКАХ'
puts '=============================================='

begin
  # Проверяем что колбэки добавлены в ServicePoint
  puts "\n📋 ПРОВЕРКА КОЛБЭКОВ SERVICE POINT"
  puts "================================="
  
  create_callbacks = ServicePoint._create_callbacks.map(&:filter)
  puts "Create callbacks: #{create_callbacks}"
  
  update_callbacks = ServicePoint._update_callbacks.map(&:filter)
  puts "Update callbacks: #{update_callbacks}"
  
  # Проверяем методы EmailTemplateMailer
  puts "\n📧 ПРОВЕРКА МЕТОДОВ EMAIL MAILER"
  puts "==============================="
  
  mailer_methods = EmailTemplateMailer.instance_methods(false)
  service_point_methods = mailer_methods.select { |m| m.to_s.include?('service_point') }
  puts "Service point methods: #{service_point_methods}"
  
  # Проверяем типы шаблонов
  puts "\n📝 ПРОВЕРКА ТИПОВ ШАБЛОНОВ"
  puts "========================="
  
  template_types = EmailTemplate.template_types
  service_point_template_types = template_types.select { |k, v| k.include?('service_point') }
  puts "Service point template types:"
  service_point_template_types.each do |key, value|
    puts "  #{key}: #{value}"
  end
  
  # Тестируем Telegram уведомления
  puts "\n📱 ТЕСТИРОВАНИЕ TELEGRAM УВЕДОМЛЕНИЙ"
  puts "==================================="
  
  # Получаем первую сервисную точку
  service_point = ServicePoint.first
  if service_point
    puts "✅ Найдена сервисная точка: #{service_point.name}"
    
    # Тестируем разные типы уведомлений
    notifications = [
      'telegram_admin_service_point_created',
      'telegram_admin_service_point_changed',
      'telegram_admin_service_point_status_changed'
    ]
    
    notifications.each do |notification_type|
      puts "\n📱 Тестируем: #{notification_type}"
      
      begin
        job = BookingNotificationJob.new
        job.send(:send_telegram_service_point_notification, service_point.id, notification_type.gsub('telegram_', ''))
        puts "   ✅ Уведомление обработано"
      rescue => e
        puts "   ❌ Ошибка: #{e.message}"
      end
      
      sleep(1) # Пауза между сообщениями
    end
    
  else
    puts "❌ Нет сервисных точек в системе"
  end
  
  puts "\n📊 СТАТИСТИКА СИСТЕМЫ"
  puts "===================="
  puts "Всего сервисных точек: #{ServicePoint.count}"
  puts "Активных: #{ServicePoint.where(is_active: true).count}"
  puts "Работающих: #{ServicePoint.where(work_status: 'working').count}"
  puts "Временно закрытых: #{ServicePoint.where(work_status: 'temporarily_closed').count}"
  
rescue => e
  puts "❌ Ошибка: #{e.message}"
  puts "   #{e.backtrace.first(3).join('\n   ')}"
end

puts "\n🎯 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"
puts "Логика уведомлений о сервисных точках интегрирована." 