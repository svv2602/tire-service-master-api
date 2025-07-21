#!/usr/bin/env ruby

puts "🔧 СПЕЦИАЛЬНЫЙ ТЕСТ ШАБЛОНА admin_booking_cancelled"
puts "=================================================="

booking = Booking.first
mailer = EmailTemplateMailer.new

# Получаем шаблон
template = EmailTemplate.find_by(template_type: 'admin_booking_cancelled', language: 'uk')

puts "📧 Шаблон: #{template.name}"
puts "📝 Subject: #{template.subject}"
puts "🔤 Subject encoding: #{template.subject.encoding}"

# Получаем переменные
variables = mailer.send(:build_booking_variables, booking)

puts "\n🔄 ПРОЦЕСС ЗАМЕНЫ ПЕРЕМЕННЫХ:"
puts "================================"

# Ручная замена переменных (как в методе replace_variables)
subject_copy = template.subject.dup
puts "1️⃣ Исходный subject: #{subject_copy} (#{subject_copy.encoding})"

variables.each do |key, value|
  placeholder = "{#{key}}"
  if subject_copy.include?(placeholder)
    puts "   Заменяем #{placeholder} на #{value} (#{value.encoding})"
    subject_copy.gsub!(placeholder, value.to_s)
    puts "   Результат: #{subject_copy} (#{subject_copy.encoding})"
  end
end

puts "\n2️⃣ Финальный subject: #{subject_copy} (#{subject_copy.encoding})"

# Проверяем метод replace_variables
puts "\n🧪 ТЕСТ МЕТОДА replace_variables:"
puts "================================"

replaced_subject = mailer.send(:replace_variables, template.subject, variables)
puts "📝 Результат: #{replaced_subject} (#{replaced_subject.encoding})"

# Создаем письмо и проверяем каждый этап
puts "\n📧 СОЗДАНИЕ ПИСЬМА:"
puts "=================="

begin
  mail = mailer.send_by_template('admin_booking_cancelled', 'svv@invelta.com.ua', variables)
  
  if mail
    puts "✅ Mail создан успешно!"
    puts "📝 Mail subject: #{mail.subject} (#{mail.subject.encoding})"
    puts "🔤 Mail charset: #{mail.charset}"
    puts "📧 Content-Type: #{mail.content_type}"
    
    # Проверяем заголовки
    puts "\n📋 ЗАГОЛОВКИ ПИСЬМА:"
    mail.header_fields.each do |field|
      if field.name.downcase.include?('content') || field.name.downcase.include?('subject')
        puts "   #{field.name}: #{field.value}"
      end
    end
    
    # Отправляем письмо
    puts "\n📬 ОТПРАВКА ПИСЬМА..."
    mail.deliver!
    puts "✅ ОТПРАВЛЕНО!"
    
  else
    puts "❌ Mail не создан"
  end
  
rescue => e
  puts "❌ Ошибка: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join(', ')}"
end

puts "\n🎯 ИТОГ:"
puts "======="
puts "📧 Специальный тест для admin_booking_cancelled выполнен"
puts "📬 Проверьте svv@invelta.com.ua"
puts "🔍 Если проблема остается, проверим SMTP настройки" 