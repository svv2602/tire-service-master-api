#!/usr/bin/env ruby

puts '📋 Последние 5 пользователей в системе:'
User.last(5).each do |user|
  puts "ID: #{user.id}, Phone: #{user.phone}, Email: #{user.email}, Role: #{user.role&.name}"
end

puts "\n🔧 Создаю тестового пользователя с номером 0000001111:"
begin
  client_role = UserRole.find_by(name: 'client')
  user = User.create!(
    first_name: 'Тест',
    last_name: 'Пользователь',
    phone: '0000001111',
    email: 'test0000001111@example.com',
    password: '0000001111',
    password_confirmation: '0000001111',
    role: client_role
  )
  puts "✅ Пользователь создан: ID=#{user.id}, Phone=#{user.phone}"
  
  # Создаем клиента если его нет
  unless user.client
    client = Client.create!(user: user)
    puts "✅ Клиент создан: ID=#{client.id}"
  end
  
  puts "\n🔐 Проверяем авторизацию:"
  puts "Можно войти с логином: #{user.phone} или #{user.email}"
  puts "Пароль: 0000001111"
  
rescue => e
  puts "❌ Ошибка создания: #{e.message}"
  puts "Детали: #{e.backtrace.first(3).join('\n')}"
end 