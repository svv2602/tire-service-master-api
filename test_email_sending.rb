#!/usr/bin/env ruby

# Скрипт для тестирования отправки email
# Использование: rails runner test_email_sending.rb your-email@example.com

puts "🧪 Тестирование системы отправки email"
puts "=" * 50

# Получаем email из аргументов
recipient_email = ARGV[0]

if recipient_email.blank?
  puts "❌ Ошибка: не указан email получателя"
  puts "Использование: rails runner test_email_sending.rb your-email@example.com"
  exit 1
end

puts "📧 Email получателя: #{recipient_email}"

# 1. Проверяем настройки SMTP
puts "\n1️⃣ Проверка настроек SMTP..."
smtp_settings = Rails.application.config.action_mailer.smtp_settings || {}

if smtp_settings.blank?
  puts "❌ SMTP настройки не найдены!"
  puts "Проверьте переменные окружения: SMTP_ADDRESS, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD"
  exit 1
end

puts "✅ SMTP настройки:"
puts "  - Адрес: #{smtp_settings[:address] || 'НЕ НАСТРОЕНО'}"
puts "  - Порт: #{smtp_settings[:port] || 'НЕ НАСТРОЕНО'}"
puts "  - Домен: #{smtp_settings[:domain] || 'НЕ НАСТРОЕНО'}"
puts "  - Пользователь: #{smtp_settings[:user_name] ? '***настроено***' : 'НЕ НАСТРОЕНО'}"
puts "  - Пароль: #{smtp_settings[:password] ? '***настроено***' : 'НЕ НАСТРОЕНО'}"

# 2. Проверяем наличие шаблонов
puts "\n2️⃣ Проверка шаблонов в базе данных..."
templates = EmailTemplate.where(is_active: true)

if templates.empty?
  puts "❌ Активные email шаблоны не найдены!"
  puts "Запустите seeds: rails runner 'load \"db/seeds/email_templates_and_variables.rb\"'"
  exit 1
end

puts "✅ Найдено #{templates.count} активных шаблонов:"
templates.each do |template|
  puts "  - #{template.id}: #{template.name} (#{template.template_type})"
end

# 3. Отправляем простой тестовый email
puts "\n3️⃣ Отправка простого тестового email..."
begin
  TestMailer.simple_test_email(recipient_email).deliver_now
  puts "✅ Простой тестовый email отправлен успешно!"
rescue => e
  puts "❌ Ошибка отправки простого email: #{e.message}"
  puts "Детали: #{e.backtrace.first(3).join('\n')}"
  exit 1
end

# 4. Отправляем email с использованием шаблона
puts "\n4️⃣ Отправка email с использованием шаблона..."

# Выбираем первый доступный шаблон
test_template = templates.first
puts "Используем шаблон: #{test_template.name} (ID: #{test_template.id})"

# Полный набор тестовых данных
test_variables = {
  # Клиент
  'client_name' => 'Тест Тестович',
  'client_email' => recipient_email,
  'client_phone' => '+38 (067) 123-45-67',
  'client_first_name' => 'Тест',
  'client_last_name' => 'Тестович',
  
  # Бронирование
  'booking_id' => '#TEST123',
  'booking_date' => Date.current.strftime('%d.%m.%Y'),
  'booking_time' => '14:30',
  'booking_status' => 'Підтверджено',
  'booking_notes' => 'Тестове бронювання',
  
  # Сервисная точка
  'service_point_name' => 'СТО Тестовий',
  'service_point_address' => 'вул. Тестова, 1, Київ',
  'service_point_phone' => '+38 (044) 555-12-34',
  'service_point_email' => 'test@tireservice.ua',
  'service_point_city' => 'Київ',
  
  # Услуги
  'service_name' => 'Тестова послуга',
  'service_category' => 'Тестування',
  'service_price' => '1000 грн',
  'service_duration' => '60 хвилин',
  'service_description' => 'Повний комплекс тестових послуг',
  
  # Автомобиль
  'car_brand' => 'Toyota',
  'car_model' => 'Camry',
  'car_year' => '2020',
  'license_plate' => 'ТЕ1234СТ',
  
  # Система
  'company_name' => 'Tire Service Master',
  'support_email' => 'support@tireservice.ua',
  'support_phone' => '+38 (044) 111-22-33',
  'website_url' => 'https://tireservice.ua',
  'current_date' => Date.current.strftime('%d.%m.%Y'),
  'current_time' => Time.current.strftime('%H:%M')
}

# Добавляем кастомные переменные из базы данных
test_template.custom_variables.each do |custom_var|
  test_variables[custom_var.name] = custom_var.example_value || "[#{custom_var.name}]"
end

puts "Кастомные переменные:"
test_template.custom_variables.each do |custom_var|
  puts "  - #{custom_var.name}: #{custom_var.example_value&.truncate(50) || '[не задано]'}"
end

puts "Переменных для замены: #{test_variables.keys.size}"

begin
  TestMailer.send_template_email(
    test_template.id,
    recipient_email,
    test_variables
  ).deliver_now
  
  puts "✅ Email с шаблоном отправлен успешно!"
  puts "Тема: #{test_template.subject.gsub(/\{[^}]+\}/) { |match| test_variables[match[1..-2]] || match }}"
  
rescue => e
  puts "❌ Ошибка отправки email с шаблоном: #{e.message}"
  puts "Детали: #{e.backtrace.first(3).join('\n')}"
  exit 1
end

# 5. Итоги
puts "\n🎉 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО УСПЕШНО!"
puts "=" * 50
puts "📧 Отправлено 2 email на адрес: #{recipient_email}"
puts "1. Простое тестовое сообщение"
puts "2. Email с шаблоном: #{test_template.name}"
puts ""
puts "Проверьте почтовый ящик (включая спам)."
puts ""
puts "🔧 Для отправки других шаблонов используйте API:"
puts "POST /api/v1/email_test/send_template"
puts "Параметры: template_id, recipient_email" 