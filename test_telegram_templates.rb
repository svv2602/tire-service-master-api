#!/usr/bin/env ruby

require_relative 'config/environment'

puts "🧪 Тестирование TelegramService с шаблонами из БД"
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
  
  # Инициализируем TelegramService
  puts "\n📱 Инициализация TelegramService..."
  telegram_service = TelegramService.new
  puts "✅ TelegramService инициализирован"
  
  # Тестируем разные типы уведомлений
  notification_types = [
    'booking_confirmation',
    'booking_cancelled', 
    'booking_reminder',
    'service_completed',
    'review_request'
  ]
  
  puts "\n🧪 Тестирование шаблонов уведомлений:"
  puts "-" * 40
  
  notification_types.each do |type|
    puts "\n📧 Тип: #{type}"
    
    # Проверяем наличие шаблона в БД
    template = EmailTemplate.where(
      template_type: type,
      language: 'uk',
      channel_type: 'telegram',
      is_active: true
    ).first
    
    if template
      puts "✅ Шаблон найден в БД: #{template.name}"
    else
      puts "⚠️  Шаблон НЕ найден в БД, будет использован fallback"
    end
    
    # Форматируем сообщение
    begin
      message = telegram_service.format_booking_notification(booking, type, 'uk')
      puts "📝 Сообщение (первые 100 символов):"
      puts message[0..100] + (message.length > 100 ? "..." : "")
      puts "✅ Форматирование успешно"
    rescue => e
      puts "❌ Ошибка форматирования: #{e.message}"
    end
    
    puts "-" * 20
  end
  
  # Проверяем статистику шаблонов
  puts "\n📊 Статистика шаблонов Telegram:"
  telegram_templates = EmailTemplate.where(channel_type: 'telegram', is_active: true)
  puts "📱 Всего Telegram шаблонов: #{telegram_templates.count}"
  
  telegram_templates.group(:language).count.each do |lang, count|
    puts "🌍 #{lang.upcase}: #{count} шаблонов"
  end
  
  telegram_templates.group(:template_type).count.each do |type, count|
    puts "📧 #{type}: #{count} шаблонов"
  end
  
  puts "\n✅ Тестирование завершено успешно!"
  
rescue => e
  puts "\n❌ Ошибка во время тестирования:"
  puts e.message
  puts e.backtrace.first(5).join("\n")
  exit 1
end 