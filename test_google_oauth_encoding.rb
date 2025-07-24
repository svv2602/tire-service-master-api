#!/usr/bin/env ruby
# encoding: utf-8

puts "🔧 ТЕСТ КОДИРОВКИ GOOGLE OAUTH"
puts "=============================="

# Симулируем данные Google OAuth с кириллицей
google_user_data = {
  provider_user_id: "123456789",
  email: "test@gmail.com", 
  first_name: "Олександр",
  last_name: "Петренко"
}

puts "📋 Исходные данные Google OAuth:"
puts "first_name: #{google_user_data[:first_name].inspect}"
puts "last_name: #{google_user_data[:last_name].inspect}"
puts "first_name encoding: #{google_user_data[:first_name].encoding}"
puts "last_name encoding: #{google_user_data[:last_name].encoding}"

# Проверяем кодировку строк
puts "\n🔍 АНАЛИЗ КОДИРОВКИ:"
puts "first_name bytes: #{google_user_data[:first_name].bytes.inspect}"
puts "last_name bytes: #{google_user_data[:last_name].bytes.inspect}"

# Принудительно устанавливаем UTF-8
first_name_utf8 = google_user_data[:first_name].force_encoding('UTF-8')
last_name_utf8 = google_user_data[:last_name].force_encoding('UTF-8')

puts "\n✅ ПОСЛЕ ПРИНУДИТЕЛЬНОЙ UTF-8:"
puts "first_name: #{first_name_utf8.inspect}"
puts "last_name: #{last_name_utf8.inspect}"
puts "first_name valid?: #{first_name_utf8.valid_encoding?}"
puts "last_name valid?: #{last_name_utf8.valid_encoding?}"

# Создаем пользователя через ActiveRecord
puts "\n💾 СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ В БД:"

begin
  # Находим роль клиента
  client_role = UserRole.find_by(name: 'client')
  unless client_role
    puts "❌ Роль 'client' не найдена"
    exit 1
  end

  # Генерируем одинаковый пароль
  password = SecureRandom.hex(10)

  # Создаем пользователя
  user = User.new(
    email: google_user_data[:email],
    first_name: first_name_utf8,
    last_name: last_name_utf8,
    password: password,
    password_confirmation: password,
    role: client_role,
    email_verified: true
  )

  if user.save
    puts "✅ Пользователь создан успешно!"
    puts "ID: #{user.id}"
    puts "Email: #{user.email}"
    puts "First name: #{user.first_name.inspect}"
    puts "Last name: #{user.last_name.inspect}"
    
    # Создаем клиента
    client = Client.create!(user: user, preferred_notification_method: 'email')
    puts "✅ Клиент создан: ID #{client.id}"
    
    # Проверяем данные из базы
    puts "\n🔍 ПРОВЕРКА ДАННЫХ ИЗ БД:"
    reloaded_user = User.find(user.id)
    puts "Из БД first_name: #{reloaded_user.first_name.inspect}"
    puts "Из БД last_name: #{reloaded_user.last_name.inspect}"
    puts "Из БД first_name encoding: #{reloaded_user.first_name.encoding}"
    puts "Из БД last_name encoding: #{reloaded_user.last_name.encoding}"
    
    # Создаем социальный аккаунт
    if defined?(UserSocialAccount)
      social_account = UserSocialAccount.create!(
        user: user,
        provider: 'google',
        provider_user_id: google_user_data[:provider_user_id]
      )
      puts "✅ Социальный аккаунт создан: ID #{social_account.id}"
    end
    
    # Тестируем JSON сериализацию (как это происходит в API)
    puts "\n📡 ТЕСТ JSON СЕРИАЛИЗАЦИИ:"
    json_data = {
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role.name
      }
    }
    
    json_string = json_data.to_json
    puts "JSON: #{json_string}"
    
    parsed_json = JSON.parse(json_string)
    puts "Parsed first_name: #{parsed_json['user']['first_name'].inspect}"
    puts "Parsed last_name: #{parsed_json['user']['last_name'].inspect}"
    
  else
    puts "❌ Ошибка создания пользователя:"
    user.errors.full_messages.each { |msg| puts "  - #{msg}" }
  end

rescue => e
  puts "❌ Исключение: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n🎯 РЕЗУЛЬТАТ:"
puts "Тест завершен. Проверьте отображение в профиле пользователя." 