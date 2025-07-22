#!/usr/bin/env ruby

require_relative 'config/environment'

puts "🔔 Тестирование PushService с шаблонами из БД"
puts "=" * 60

begin
  # Создаем тестовое бронирование
  puts "📋 Создание тестового бронирования..."
  
  service_point = ServicePoint.first
  if service_point.nil?
    puts "❌ Нет сервисных точек в БД"
    exit 1
  end
  
  booking = Booking.new(
    id: 999,
    start_time: 1.day.from_now,
    service_point: service_point,
    car_brand: "Toyota",
    car_model: "Camry",
    license_plate: "AA1234BB",
    service_recipient_first_name: "Тестовый",
    service_recipient_last_name: "Клиент",
    service_recipient_phone: "+380671234567",
    service_recipient_email: "test@example.com",
    notes: "Тестовое бронирование"
  )
  
  puts "✅ Тестовое бронирование создано"
  
  # Инициализируем PushService
  puts "\n🔔 Инициализация PushService..."
  push_service = PushService.new
  puts "✅ PushService инициализирован"
  
  # Тестируем разные типы уведомлений
  notification_types = [
    'booking_confirmation',
    'booking_cancelled', 
    'booking_reminder',
    'service_completed',
    'review_request'
  ]
  
  puts "\n🧪 Тестирование шаблонов Push уведомлений:"
  puts "-" * 40
  
  notification_types.each do |type|
    puts "\n🔔 Тип: #{type}"
    
    # Проверяем наличие шаблона в БД
    template = EmailTemplate.where(
      template_type: type,
      language: 'uk',
      channel_type: 'push',
      is_active: true
    ).first
    
    if template
      puts "✅ Шаблон найден в БД: #{template.name}"
      puts "📝 Subject: #{template.subject}"
    else
      puts "⚠️  Шаблон НЕ найден в БД, будет использован fallback"
    end
    
    # Форматируем сообщение
    begin
      message_data = push_service.format_booking_notification(booking, type, 'uk')
      puts "📱 Push уведомление:"
      puts "   📌 Title: #{message_data[:title]}"
      puts "   📄 Body: #{message_data[:body][0..80]}#{message_data[:body].length > 80 ? '...' : ''}"
      puts "✅ Форматирование успешно"
    rescue => e
      puts "❌ Ошибка форматирования: #{e.message}"
    end
    
    puts "-" * 20
  end
  
  # Проверяем статистику шаблонов
  puts "\n📊 Статистика шаблонов Push:"
  push_templates = EmailTemplate.where(channel_type: 'push', is_active: true)
  puts "🔔 Всего Push шаблонов: #{push_templates.count}"
  
  push_templates.group(:language).count.each do |lang, count|
    puts "🌍 #{lang.upcase}: #{count} шаблонов"
  end
  
  push_templates.group(:template_type).count.each do |type, count|
    puts "📱 #{type}: #{count} шаблонов"
  end
  
  # Тестируем fallback методы
  puts "\n🔧 Тестирование fallback методов:"
  
  notification_types.each do |type|
    fallback_data = push_service.send(:format_booking_notification_fallback, booking, type)
    puts "📱 #{type}: fallback title=#{fallback_data[:title]}"
  end
  
  puts "\n✅ Тестирование завершено успешно!"
  
rescue => e
  puts "\n❌ Ошибка во время тестирования:"
  puts e.message
  puts e.backtrace.first(5).join("\n")
  exit 1
end 