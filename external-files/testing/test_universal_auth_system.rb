#!/usr/bin/env ruby

# Тестирование универсальной системы авторизации
# Проверяет вход по email/телефону и восстановление пароля

require 'net/http'
require 'json'
require 'uri'

API_BASE = 'http://localhost:8000/api/v1'

class UniversalAuthTester
  def initialize
    @results = []
  end

  def run_all_tests
    puts "🚀 Тестирование универсальной системы авторизации"
    puts "=" * 60
    
    test_login_with_email
    test_login_with_phone
    test_forgot_password_email
    test_forgot_password_phone
    test_invalid_login
    
    print_results
  end

  private

  def test_login_with_email
    puts "\n📧 Тест: Вход по email"
    
    payload = {
      auth: {
        login: 'admin@test.com',
        password: 'admin123'
      }
    }
    
    response = make_request('POST', '/auth/login', payload)
    
    if response && response['user'] && response['access_token']
      log_success("Вход по email успешен", {
        user_id: response['user']['id'],
        email: response['user']['email'],
        role: response['user']['role']
      })
    else
      log_error("Вход по email не удался", response)
    end
  end

  def test_login_with_phone
    puts "\n📱 Тест: Вход по телефону"
    
    # Сначала создаем пользователя с телефоном
    create_test_user_with_phone
    
    payload = {
      auth: {
        login: '+79991234567',
        password: 'test123'
      }
    }
    
    response = make_request('POST', '/auth/login', payload)
    
    if response && response['user'] && response['access_token']
      log_success("Вход по телефону успешен", {
        user_id: response['user']['id'],
        phone: response['user']['phone'],
        role: response['user']['role']
      })
    else
      log_error("Вход по телефону не удался", response)
    end
  end

  def test_forgot_password_email
    puts "\n📧 Тест: Восстановление пароля по email"
    
    payload = {
      login: 'admin@test.com'
    }
    
    response = make_request('POST', '/password/forgot', payload)
    
    if response && response['message']
      log_success("Запрос восстановления по email отправлен", {
        message: response['message']
      })
    else
      log_error("Восстановление по email не удалось", response)
    end
  end

  def test_forgot_password_phone
    puts "\n📱 Тест: Восстановление пароля по телефону"
    
    payload = {
      login: '+79991234567'
    }
    
    response = make_request('POST', '/password/forgot', payload)
    
    if response && response['message']
      log_success("Запрос восстановления по телефону отправлен", {
        message: response['message']
      })
    else
      log_error("Восстановление по телефону не удалось", response)
    end
  end

  def test_invalid_login
    puts "\n❌ Тест: Неверные данные входа"
    
    payload = {
      auth: {
        login: 'nonexistent@test.com',
        password: 'wrongpassword'
      }
    }
    
    response = make_request('POST', '/auth/login', payload)
    
    if response && response['error']
      log_success("Корректная обработка неверных данных", {
        error: response['error']
      })
    else
      log_error("Неправильная обработка неверных данных", response)
    end
  end

  def create_test_user_with_phone
    puts "👤 Создание тестового пользователя с телефоном..."
    
    # Создаем пользователя через Rails console
    system("cd #{File.dirname(__FILE__)}/../../ && rails runner \"
      role = UserRole.find_by(name: 'client') || UserRole.create!(name: 'client')
      user = User.find_or_create_by(phone: '+79991234567') do |u|
        u.first_name = 'Test'
        u.last_name = 'User'
        u.password = 'test123'
        u.password_confirmation = 'test123'
        u.role = role
      end
      Client.find_or_create_by(user: user)
      puts 'Тестовый пользователь создан'
    \"")
  end

  def make_request(method, endpoint, payload = nil)
    uri = URI("#{API_BASE}#{endpoint}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 10
    
    case method
    when 'POST'
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json if payload
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    end
    
    begin
      response = http.request(request)
      JSON.parse(response.body) if response.body
    rescue => e
      puts "❌ Ошибка запроса: #{e.message}"
      nil
    end
  end

  def log_success(message, data = {})
    @results << { status: :success, message: message, data: data }
    puts "✅ #{message}"
    puts "   #{data}" unless data.empty?
  end

  def log_error(message, data = {})
    @results << { status: :error, message: message, data: data }
    puts "❌ #{message}"
    puts "   #{data}" unless data.empty?
  end

  def print_results
    puts "\n" + "=" * 60
    puts "📊 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ"
    puts "=" * 60
    
    success_count = @results.count { |r| r[:status] == :success }
    total_count = @results.length
    
    puts "✅ Успешно: #{success_count}/#{total_count}"
    puts "❌ Ошибки: #{total_count - success_count}/#{total_count}"
    
    if success_count == total_count
      puts "\n🎉 Все тесты прошли успешно!"
      puts "🔐 Универсальная система авторизации работает корректно"
    else
      puts "\n⚠️  Некоторые тесты не прошли. Проверьте настройки."
    end
    
    puts "\n📋 Детали:"
    @results.each_with_index do |result, index|
      icon = result[:status] == :success ? "✅" : "❌"
      puts "#{index + 1}. #{icon} #{result[:message]}"
    end
  end
end

# Запускаем тесты
if __FILE__ == $0
  tester = UniversalAuthTester.new
  tester.run_all_tests
end 