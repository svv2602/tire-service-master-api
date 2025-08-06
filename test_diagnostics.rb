#!/usr/bin/env ruby
require './config/environment'

puts "Тестирование диагностики настроек..."

# Тест GoogleOauthSetting
begin
  oauth = GoogleOauthSetting.current
  puts "✅ GoogleOauthSetting.current работает"
  puts "   - enabled: #{oauth.enabled?}"
  puts "   - system_status: #{oauth.system_status}"
  puts "   - ready_for_production: #{oauth.ready_for_production?}"
rescue => e
  puts "❌ Ошибка GoogleOauthSetting: #{e.message}"
end

# Тест EmailSetting
begin
  email = EmailSetting.current
  puts "✅ EmailSetting.current работает"
  puts "   - enabled: #{email.enabled?}"
  puts "   - ready_for_production: #{email.ready_for_production?}"
rescue => e
  puts "❌ Ошибка EmailSetting: #{e.message}"
end

# Тест PushSetting
begin
  push = PushSetting.current
  puts "✅ PushSetting.current работает"
  puts "   - enabled: #{push.enabled?}"
  puts "   - ready_for_production: #{push.ready_for_production?}"
rescue => e
  puts "❌ Ошибка PushSetting: #{e.message}"
end

# Тест TelegramSetting
begin
  telegram = TelegramSetting.current
  puts "✅ TelegramSetting.current работает"
  puts "   - enabled: #{telegram.enabled?}"
  puts "   - ready_for_production: #{telegram.ready_for_production?}"
rescue => e
  puts "❌ Ошибка TelegramSetting: #{e.message}"
end

# Тест SystemSetting
begin
  system_settings = SystemSetting.all
  puts "✅ SystemSetting работает, всего настроек: #{system_settings.count}"
rescue => e
  puts "❌ Ошибка SystemSetting: #{e.message}"
end

# Тест NotificationChannelSetting
begin
  channels = NotificationChannelSetting.all
  puts "✅ NotificationChannelSetting работает, всего каналов: #{channels.count}"
rescue => e
  puts "❌ Ошибка NotificationChannelSetting: #{e.message}"
end

puts "\nТест завершен!"