puts '📧 ОТПРАВКА НА КОРПОРАТИВНЫЙ EMAIL'
puts '=' * 40

# Создаем или находим пользователя для корпоративного email
user = User.find_by(email: 'snisar.vv@tot.biz.ua')
unless user
  puts 'Создаем пользователя для корпоративного email...'
  user = User.create!(
    email: 'snisar.vv@tot.biz.ua',
    first_name: 'Валерий',
    last_name: 'Снисар',
    phone: '+380504874375',
    password: 'test123',
    password_confirmation: 'test123',
    is_active: true,
    email_verified: true,
    role: UserRole.find_by(name: 'client')
  )
  puts "Пользователь создан: #{user.email}"
else
  puts "Найден пользователь: #{user.email}"
end

# Генерируем токен
reset_token = "corp_test_#{Time.current.to_i}"
reset_expires_at = 2.hours.from_now

# Сохраняем токен
user.update!(
  password_reset_token: reset_token,
  password_reset_sent_at: reset_expires_at
)

puts "Токен: #{reset_token}"
puts "Действителен до: #{reset_expires_at.strftime('%d.%m.%Y %H:%M')}"

# Отправляем письмо восстановления пароля
begin
  puts 'Отправляем письмо восстановления пароля...'
  result = EmailTemplateMailer.password_reset(user.id, reset_token, 'ru').deliver_now
  
  puts '✅ ПИСЬМО ВОССТАНОВЛЕНИЯ ОТПРАВЛЕНО!'
  puts "Message ID: #{result.message_id}"
  puts "Тема: #{result.subject}"
  puts "От: #{result.from.join(', ')}"
  puts "Кому: #{result.to.join(', ')}"
  
rescue => e
  puts "❌ Ошибка: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end

puts ''
puts '🔗 Ссылка для сброса пароля:'
puts "http://localhost:3008/auth/reset-password?token=#{reset_token}"
puts ''
puts '📧 Проверьте почту snisar.vv@tot.biz.ua'
puts '✨ В письме должны быть заменены все переменные!' 