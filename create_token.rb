#!/usr/bin/env ruby

# Загружаем Rails окружение
require_relative 'config/environment'

# Находим админа
user = User.find_by(email: 'admin@test.com')

if user
  # Создаем access токен
  token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
  
  puts "Новый access токен для admin@test.com:"
  puts token
  puts ""
  puts "Для установки в браузере выполните в консоли:"
  puts "document.cookie = 'access_token=#{token}; path=/; max-age=3600'"
  puts ""
  puts "Или используйте в заголовке Authorization:"
  puts "Authorization: Bearer #{token}"
else
  puts "Пользователь admin@test.com не найден"
end