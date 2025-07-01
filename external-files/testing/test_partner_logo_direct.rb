#!/usr/bin/env ruby

# Простой тест для проверки загрузки логотипа партнера
require 'net/http'
require 'uri'
require 'json'

API_BASE = 'http://localhost:8000/api/v1'

def login_admin
  uri = URI("#{API_BASE}/auth/login")
  http = Net::HTTP.new(uri.host, uri.port)
  
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = {
    auth: {
      email: 'admin@test.com',
      password: 'admin123'
    }
  }.to_json
  
  response = http.request(request)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    puts "✅ Авторизация успешна"
    return data['tokens']['access']
  else
    puts "❌ Ошибка авторизации: #{response.body}"
    return nil
  end
end

def test_partner_update_with_logo(token, partner_id)
  uri = URI("#{API_BASE}/partners/#{partner_id}")
  http = Net::HTTP.new(uri.host, uri.port)
  
  # Создаем простой тестовый файл
  logo_content = "fake image data for testing"
  
  # Создаем multipart/form-data запрос
  boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
  
  body = []
  body << "--#{boundary}"
  body << 'Content-Disposition: form-data; name="partner[company_name]"'
  body << ""
  body << "Тестовая компания #{Time.now.to_i}"
  
  body << "--#{boundary}"
  body << 'Content-Disposition: form-data; name="partner[contact_person]"'
  body << ""
  body << "Тестовый контакт"
  
  body << "--#{boundary}"
  body << 'Content-Disposition: form-data; name="partner[legal_address]"'
  body << ""
  body << "Тестовый адрес"
  
  body << "--#{boundary}"
  body << 'Content-Disposition: form-data; name="partner[logo]"; filename="test_logo.jpg"'
  body << 'Content-Type: image/jpeg'
  body << ""
  body << logo_content
  
  body << "--#{boundary}--"
  
  request = Net::HTTP::Put.new(uri)
  request['Authorization'] = "Bearer #{token}"
  request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
  request.body = body.join("\r\n")
  
  puts "🔄 Отправляем запрос на обновление партнера #{partner_id}..."
  response = http.request(request)
  
  puts "📊 Статус ответа: #{response.code}"
  
  if response.code == '200'
    puts "✅ Запрос обработан успешно"
    begin
      # Принудительно устанавливаем кодировку UTF-8
      response_body = response.body.force_encoding('UTF-8')
      data = JSON.parse(response_body)
      puts "📄 Данные партнера получены"
      
      if data['logo'] && data['logo'] != data['logo_url']
        puts "✅ Логотип успешно загружен: #{data['logo']}"
      else
        puts "❌ Логотип не был загружен. Поле logo: #{data['logo']}"
        puts "📝 logo_url: #{data['logo_url']}"
      end
    rescue JSON::ParserError => e
      puts "❌ Ошибка парсинга JSON: #{e.message}"
      puts "📄 Первые 200 символов ответа: #{response.body[0..200]}"
    rescue => e
      puts "❌ Ошибка: #{e.message}"
    end
  else
    puts "❌ Ошибка обновления партнера: #{response.code}"
    puts "📄 Тело ответа: #{response.body[0..200]}"
  end
end

# Основной тест
puts "🧪 Тестирование загрузки логотипа партнера"
puts "=" * 50

token = login_admin
if token
  test_partner_update_with_logo(token, 1)
else
  puts "❌ Не удалось получить токен авторизации"
end 