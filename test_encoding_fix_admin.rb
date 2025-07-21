#!/usr/bin/env ruby

puts "🔍 ДЕТАЛЬНАЯ ПРОВЕРКА КОДИРОВКИ АДМИНСКИХ ПИСЕМ"
puts "==============================================="

booking = Booking.first
mailer = EmailTemplateMailer.new
variables = mailer.send(:build_booking_variables, booking)

puts "📋 Booking ID: #{booking.id}"
puts "🔤 Переменные:"
variables.each do |key, value|
  puts "   #{key}: #{value} (#{value.encoding})"
end

puts "\n" + "="*50

# Проверяем каждый админский шаблон
admin_templates = ['admin_booking_changed', 'admin_booking_cancelled']

admin_templates.each_with_index do |template_type, index|
  puts "\n#{index + 1}️⃣ ТЕСТ: #{template_type}"
  puts "-" * 30
  
  # Получаем шаблон из БД
  template = EmailTemplate.find_by(template_type: template_type, is_active: true, language: 'uk')
  if template
    puts "📧 Шаблон найден: #{template.name}"
    puts "📝 Subject из БД: #{template.subject} (#{template.subject.encoding})"
    puts "💾 Body encoding: #{template.body.encoding}"
    
    # Заменяем переменные
    subject_with_vars = template.subject.dup
    variables.each do |key, value|
      placeholder = "{#{key}}"
      subject_with_vars.gsub!(placeholder, value.to_s)
    end
    
    puts "🔄 Subject после замены: #{subject_with_vars} (#{subject_with_vars.encoding})"
    
    # Создаем и отправляем письмо
    begin
      mail = mailer.send_by_template(template_type, 'svv@invelta.com.ua', variables)
      if mail
        puts "✅ Mail создан:"
        puts "   📝 Subject: #{mail.subject} (#{mail.subject.encoding})"
        puts "   🔤 Content-Type: #{mail.content_type}"
        puts "   📧 Charset: #{mail.charset}"
        
        # Отправляем
        mail.deliver!
        puts "   📬 ОТПРАВЛЕНО!"
      else
        puts "❌ Mail не создан"
      end
    rescue => e
      puts "❌ Ошибка: #{e.message}"
    end
  else
    puts "❌ Шаблон не найден"
  end
  
  puts
  sleep 1
end

puts "🎯 ИТОГ:"
puts "📧 Отправлено #{admin_templates.length} админских писем"
puts "📬 Проверьте svv@invelta.com.ua"
puts "🔤 Все письма должны иметь правильную UTF-8 кодировку" 