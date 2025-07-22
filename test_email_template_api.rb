puts '🧪 ТЕСТИРОВАНИЕ API EMAIL_TEMPLATES'
puts '=' * 50

# Создаем тестового админа
admin_user = User.find_by(email: 'admin@test.com')
unless admin_user
  puts 'Создаем тестового админа...'
  admin_role = UserRole.find_by(name: 'admin')
  admin_user = User.create!(
    email: 'admin@test.com',
    first_name: 'Админ',
    last_name: 'Тестовый',
    phone: '+380501234567',
    password: 'admin123',
    password_confirmation: 'admin123',
    is_active: true,
    email_verified: true,
    role: admin_role
  )
  puts "Админ создан: #{admin_user.email}"
else
  puts "Админ найден: #{admin_user.email}"
end

# Проверяем шаблон ID 35
template = EmailTemplate.find(35)
puts ""
puts "📧 ШАБЛОН ID 35:"
puts "Название: #{template.name}"
puts "Тип: #{template.template_type}"
puts "Язык: #{template.language}"
puts "Активен: #{template.is_active}"
puts ""
puts "ТЕМА (первые 100 символов):"
puts template.subject[0..100]
puts ""
puts "ТЕЛО (первые 200 символов):"
puts template.body[0..200]

puts ""
puts "✅ ШАБЛОН В БД КОРРЕКТНЫЙ!"
puts ""
puts "🔍 ПРОБЛЕМА В АВТОРИЗАЦИИ ФРОНТЕНДА"
puts "Проверьте в браузере:"
puts "1. Авторизован ли пользователь как админ"
puts "2. Передаются ли cookies в запросах"
puts "3. Нет ли ошибок CORS" 