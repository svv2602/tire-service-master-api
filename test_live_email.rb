#!/usr/bin/env ruby

puts "🧪 ТЕСТ ОТПРАВКИ ПИСЬМА НА ЖИВОЙ АДРЕС"
puts "=============================================="

# Находим существующее бронирование для тестирования
booking = Booking.first
if booking.nil?
  puts "❌ Нет бронирований для тестирования"
  exit 1
end

puts "📋 Используем бронирование ##{booking.id}"
puts "📧 Отправляем на: svv@invelta.com.ua"

begin
  # Отправляем письмо напрямую
  puts "📨 Отправка письма подтверждения бронирования..."
  
  # Используем синхронную отправку для тестирования
  EmailTemplateMailer.booking_confirmation(booking.id, 'svv@invelta.com.ua').deliver_now
  
  puts "✅ Письмо успешно отправлено!"
  puts "📬 Проверьте почтовый ящик: svv@invelta.com.ua"
  
rescue Net::OpenTimeout => e
  puts "❌ Таймаут подключения к SMTP серверу: #{e.message}"
  puts "🔍 Возможные причины:"
  puts "   - SMTP сервер недоступен"
  puts "   - Неправильные настройки порта"
  puts "   - Блокировка фаерволом"
  
rescue Net::SMTPAuthenticationError => e
  puts "❌ Ошибка аутентификации SMTP: #{e.message}"
  puts "🔍 Проверьте логин и пароль SMTP"
  
rescue => e
  puts "❌ Ошибка отправки: #{e.message}"
  puts "🔍 Детали: #{e.class}"
  puts "📝 Backtrace: #{e.backtrace.first(3).join('; ')}"
end

puts "\n🎯 Тест завершен!" 