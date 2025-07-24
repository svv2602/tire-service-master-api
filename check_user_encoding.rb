#!/usr/bin/env ruby
# encoding: utf-8

puts "🔍 ПРОВЕРКА ДАННЫХ ПОЛЬЗОВАТЕЛЯ В БД"
puts "===================================="

# Находим созданного пользователя
user = User.find_by(email: 'test@gmail.com')

if user
  puts "✅ Пользователь найден:"
  puts "ID: #{user.id}"
  puts "Email: #{user.email}"
  puts "First name: #{user.first_name.inspect}"
  puts "Last name: #{user.last_name.inspect}"
  puts "First name encoding: #{user.first_name.encoding}"
  puts "Last name encoding: #{user.last_name.encoding}"
  puts "First name bytes: #{user.first_name.bytes.inspect}"
  puts "Last name bytes: #{user.last_name.bytes.inspect}"
  
  puts "\n📡 СИМУЛЯЦИЯ API ОТВЕТА:"
  
  # Симулируем то, что происходит в контроллере social_auth
  response_data = {
    auth_token: "test_token",
    user: {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      phone: user.phone,
      email_verified: user.email_verified,
      phone_verified: user.phone_verified,
      role: user.role.name,
      is_active: user.is_active?,
      client_id: user.client&.id,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  }
  
  # Конвертируем в JSON как это делает Rails
  json_response = response_data.to_json
  puts "JSON ответ: #{json_response}"
  
  # Парсим обратно как это делает фронтенд
  parsed_data = JSON.parse(json_response)
  puts "\n🔄 ПОСЛЕ ПАРСИНГА JSON:"
  puts "Parsed first_name: #{parsed_data['user']['first_name'].inspect}"
  puts "Parsed last_name: #{parsed_data['user']['last_name'].inspect}"
  puts "Parsed first_name encoding: #{parsed_data['user']['first_name'].encoding}"
  puts "Parsed last_name encoding: #{parsed_data['user']['last_name'].encoding}"
  
  # Проверяем как это будет выглядеть в браузере
  puts "\n🌐 КАК ЭТО БУДЕТ В БРАУЗЕРЕ:"
  puts "Display name: #{parsed_data['user']['first_name']} #{parsed_data['user']['last_name']}"
  
  # Проверяем социальный аккаунт
  if defined?(UserSocialAccount)
    social_account = user.social_accounts.find_by(provider: 'google')
    if social_account
      puts "\n🔗 СОЦИАЛЬНЫЙ АККАУНТ:"
      puts "Provider: #{social_account.provider}"
      puts "Provider User ID: #{social_account.provider_user_id}"
    end
  end
  
else
  puts "❌ Пользователь с email test@gmail.com не найден"
end

puts "\n🎯 ЗАКЛЮЧЕНИЕ:"
puts "Если имя отображается как кракозябры, проблема в frontend обработке JSON." 