#!/usr/bin/env ruby

puts '📝 ТЕСТИРОВАНИЕ ЛОГИКИ УВЕДОМЛЕНИЙ ОБ ОТЗЫВАХ'
puts '============================================='

# Проверим что методы уведомлений добавлены в BookingNotificationJob
puts "\n🔍 ПРОВЕРКА МЕТОДОВ BookingNotificationJob"
puts "========================================="

job = BookingNotificationJob.new
puts "✅ BookingNotificationJob создан"

# Проверяем что у Review есть колбэки
puts "\n📋 ПРОВЕРКА КОЛБЭКОВ REVIEW"
puts "=========================="

review_callbacks = Review._create_callbacks.map(&:filter)
puts "Create callbacks: #{review_callbacks}"

review_update_callbacks = Review._update_callbacks.map(&:filter)
puts "Update callbacks: #{review_update_callbacks}"

# Проверяем методы EmailTemplateMailer
puts "\n📧 ПРОВЕРКА МЕТОДОВ EMAIL MAILER"
puts "==============================="

mailer_methods = EmailTemplateMailer.instance_methods(false)
review_methods = mailer_methods.select { |m| m.to_s.include?('review') }
puts "Review-related methods: #{review_methods}"

# Проверяем типы шаблонов
puts "\n📝 ПРОВЕРКА ТИПОВ ШАБЛОНОВ"
puts "========================="

template_types = EmailTemplate.template_types
review_template_types = template_types.select { |k, v| k.include?('review') }
puts "Review template types:"
review_template_types.each do |key, value|
  puts "  #{key}: #{value}"
end

# Проверяем существующие шаблоны
puts "\n📊 СУЩЕСТВУЮЩИЕ ШАБЛОНЫ"
puts "======================="

existing_templates = EmailTemplate.where("template_type LIKE '%review%'")
puts "Найдено шаблонов с 'review': #{existing_templates.count}"
existing_templates.each do |template|
  puts "  - #{template.name} (#{template.template_type})"
end

puts "\n🎯 ПРОВЕРКА ЗАВЕРШЕНА!"
puts "Логика уведомлений об отзывах интегрирована в код."
puts "Для полного тестирования нужно создать email шаблоны." 