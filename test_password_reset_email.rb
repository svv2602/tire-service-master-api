#!/usr/bin/env ruby

puts '📧 Тестируем отправку email для восстановления пароля на svv2602@gmail.com'
puts '=' * 70

# Создаем тестового пользователя или используем существующего
user = User.find_by(email: 'svv2602@gmail.com')
unless user
  puts 'Пользователь не найден, создаем тестового...'
  user = User.create!(
    email: 'svv2602@gmail.com',
    first_name: 'Сергей',
    last_name: 'Тест',
    phone: '+380501234567',
    password: 'test123',
    password_confirmation: 'test123',
    is_active: true,
    email_verified: true
  )
  puts 'Тестовый пользователь создан: ' + user.email
else
  puts 'Найден пользователь: ' + user.email
end

# Генерируем токен восстановления
reset_token = SecureRandom.urlsafe_base64(32)
reset_expires_at = 2.hours.from_now

# Сохраняем токен
user.update!(
  password_reset_token: reset_token,
  password_reset_sent_at: reset_expires_at
)

puts 'Токен сгенерирован: ' + reset_token[0..15] + '...'
puts 'Действителен до: ' + reset_expires_at.strftime('%d.%m.%Y %H:%M')

# Отправляем email
begin
  puts 'Отправляем email...'
  result = EmailTemplateMailer.password_reset(user.id, reset_token, 'ru').deliver_now
  
  puts '✅ Email отправлен успешно!'
  puts 'Message ID: ' + result.message_id.to_s if result.message_id
  puts 'Получатель: ' + result.to.join(', ')
  puts 'Тема: ' + result.subject
  puts 'Ссылка для сброса: http://localhost:3008/auth/reset-password?token=' + reset_token
  
rescue => e
  puts '❌ Ошибка отправки: ' + e.message
  puts 'Backtrace:'
  puts e.backtrace.first(5).join("\n")
end

puts ''
puts '🔍 Проверьте почтовый ящик svv2602@gmail.com'
puts '📧 Если письмо не пришло, проверьте папку "Спам"'
puts '🔗 Ссылка для тестирования: http://localhost:3008/auth/reset-password?token=' + reset_token 