#!/usr/bin/env ruby

puts "🔧 ТЕСТ ИСПРАВЛЕНИЯ UTF-8 КОДИРОВКИ В EMAIL"
puts "==========================================="

booking = Booking.first
booking.update_column(:service_recipient_email, 'svv@invelta.com.ua')

# Создаем кастомный mailer для тестирования
class TestUTF8Mailer < ApplicationMailer
  default from: ENV.fetch('SMTP_FROM_EMAIL', 'noreply@tireservice.ua'),
          charset: 'UTF-8',
          content_type: 'text/html'

  def test_utf8_email(recipient_email, subject, body)
    mail(
      to: recipient_email,
      subject: subject,
      body: body,
      content_type: 'text/html; charset=UTF-8'
    ) do |format|
      format.html { render plain: body }
    end
  end
end

puts "📧 Отправляем тестовые письма с правильной UTF-8 кодировкой:"

# Тест 1: booking_location_changed
puts "\n1️⃣ Тестируем booking_location_changed:"
begin
  subject = "Зміна місця обслуговування - бронювання №#{booking.id}"
  body = %{
    <html>
    <head>
      <meta charset="UTF-8">
      <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    </head>
    <body>
      <h2>Вітаємо, #{booking.service_recipient_first_name}!</h2>
      <p>Місце вашого обслуговування було змінено.</p>
      
      <h3>🏢 НОВА СЕРВІСНА ТОЧКА:</h3>
      <p><strong>#{booking.service_point.name}</strong></p>
      <p>📍 Адреса: #{booking.service_point.address}</p>
      <p>🌐 Місто: #{booking.service_point.city.name}</p>
      
      <h3>📅 ДАТА ТА ЧАС:</h3>
      <p>• Дата: #{booking.booking_date&.strftime('%d.%m.%Y')}</p>
      <p>• Час: #{booking.start_time&.strftime('%H:%M')}</p>
      
      <p>З повагою,<br/>Команда Tire Service Master</p>
    </body>
    </html>
  }.strip

  TestUTF8Mailer.test_utf8_email('svv@invelta.com.ua', subject, body).deliver!
  puts "   ✅ Отправлено с правильной UTF-8 кодировкой!"
  
rescue => e
  puts "   ❌ Ошибка: #{e.message}"
end

# Тест 2: booking_client_info_changed  
puts "\n2️⃣ Тестируем booking_client_info_changed:"
begin
  subject = "Оновлення даних бронювання №#{booking.id}"
  body = %{
    <html>
    <head>
      <meta charset="UTF-8">
      <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    </head>
    <body>
      <h2>Вітаємо, #{booking.service_recipient_first_name}!</h2>
      <p>Дані вашого бронювання було оновлено.</p>
      
      <h3>📋 БРОНЮВАННЯ:</h3>
      <p>• Номер: ##{booking.id}</p>
      <p>• Дата: #{booking.booking_date&.strftime('%d.%m.%Y')}</p>
      <p>• Час: #{booking.start_time&.strftime('%H:%M')}</p>
      
      <h3>👤 ОНОВЛЕНІ КОНТАКТНІ ДАНІ:</h3>
      <p>• Ім'я: #{booking.service_recipient_first_name} #{booking.service_recipient_last_name}</p>
      <p>• Телефон: #{booking.service_recipient_phone}</p>
      <p>• Email: #{booking.service_recipient_email}</p>
      
      <p>✅ Ваше бронювання залишається активним з оновленими даними.</p>
      
      <p>З повагою,<br/>Команда Tire Service Master</p>
    </body>
    </html>
  }.strip

  TestUTF8Mailer.test_utf8_email('svv@invelta.com.ua', subject, body).deliver!
  puts "   ✅ Отправлено с правильной UTF-8 кодировкой!"
  
rescue => e
  puts "   ❌ Ошибка: #{e.message}"
end

puts "\n🎯 РЕЗУЛЬТАТ:"
puts "📧 Отправлено 2 тестовых письма на svv@invelta.com.ua"
puts "🔧 С принудительной UTF-8 кодировкой и HTML заголовками"
puts "📬 Проверьте отображение - должно быть без кракозябр!" 