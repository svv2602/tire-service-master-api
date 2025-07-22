#!/usr/bin/env ruby

puts '🔍 ОТЛАДКА ЗАМЕНЫ ПЕРЕМЕННЫХ'
puts '=' * 35

# Получаем шаблон
template = EmailTemplate.find_by(template_type: 'password_reset', language: 'ru')
puts 'Шаблон: ' + template.name
puts 'Исходная тема: ' + template.subject
puts 'Исходное тело (первые 100 символов): ' + template.body[0..100]

puts ''
puts 'Переменные шаблона: ' + template.variables_array.inspect

# Создаем переменные
user = User.find_by(email: 'svv2602@gmail.com')
mailer = EmailTemplateMailer.new
variables = mailer.send(:build_user_variables, user)
variables.merge!({
  'reset_token' => 'test123',
  'reset_url' => 'http://localhost:3008/auth/reset-password?token=test123'
})

puts ''
puts 'Доступные переменные:'
variables.each { |k, v| puts "  #{k}: #{v}" }

# Тестируем замену
puts ''
puts 'ТЕСТ ЗАМЕНЫ:'
rendered = template.render_with_all_variables(variables)
puts 'Обработанная тема: ' + rendered[:subject]
puts 'Обработанное тело (первые 200 символов): ' + rendered[:body][0..200]

puts ''
puts '🔍 ПРОВЕРКА МЕТОДА render_with_all_variables:'
puts 'Класс шаблона: ' + template.class.name
puts 'Методы шаблона: ' + template.class.instance_methods(false).grep(/render/).to_s 