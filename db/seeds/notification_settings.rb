# Seeds для настроек системы уведомлений
puts "🔔 Создание настроек системы уведомлений..."

# =====================================================
# EMAIL НАСТРОЙКИ
# =====================================================

puts "📧 Создание настроек Email..."

email_setting = EmailSetting.first
if email_setting
  puts "  ✅ Настройки Email уже существуют (ID: #{email_setting.id})"
else
  email_setting = EmailSetting.create!(
    enabled: false,
    smtp_port: 587,
    smtp_authentication: nil,  # Без аутентификации по умолчанию
    smtp_starttls_auto: true,
    smtp_tls: false,
    test_mode: false,
    from_name: 'Tire Service',
    openssl_verify_mode: 'none'
  )
  puts "  ✅ Настройки Email созданы (ID: #{email_setting.id})"
end

# =====================================================
# TELEGRAM НАСТРОЙКИ
# =====================================================

puts "📱 Создание настроек Telegram..."

telegram_setting = TelegramSetting.first
if telegram_setting
  puts "  ✅ Настройки Telegram уже существуют (ID: #{telegram_setting.id})"
else
  telegram_setting = TelegramSetting.create!(
    enabled: false,
    test_mode: false,
    auto_subscription: true
  )
  puts "  ✅ Настройки Telegram созданы (ID: #{telegram_setting.id})"
end

# =====================================================
# PUSH НАСТРОЙКИ
# =====================================================

puts "📲 Создание настроек Push уведомлений..."

push_setting = PushSetting.first
if push_setting
  puts "  ✅ Настройки Push уже существуют (ID: #{push_setting.id})"
else
  push_setting = PushSetting.create!(
    enabled: false,
    test_mode: false,
    daily_limit: 1000,
    rate_limit: 100
  )
  puts "  ✅ Настройки Push созданы (ID: #{push_setting.id})"
end

# =====================================================
# GOOGLE OAUTH НАСТРОЙКИ
# =====================================================

puts "🔑 Создание настроек Google OAuth..."

google_oauth_setting = GoogleOauthSetting.first
if google_oauth_setting
  puts "  ✅ Настройки Google OAuth уже существуют (ID: #{google_oauth_setting.id})"
else
  google_oauth_setting = GoogleOauthSetting.create!(
    enabled: false,
    allow_registration: true,
    auto_verify_email: true,
    scopes_list: 'email,profile',
    redirect_uri: 'http://localhost:3008/auth/google/callback'
  )
  puts "  ✅ Настройки Google OAuth созданы (ID: #{google_oauth_setting.id})"
end

# =====================================================
# НАСТРОЙКИ КАНАЛОВ УВЕДОМЛЕНИЙ
# =====================================================

puts "📋 Создание настроек каналов уведомлений..."

channels_data = [
  {
    channel_type: 'email',
    enabled: true,
    priority: 1,
    retry_attempts: 3,
    retry_delay: 15,
    daily_limit: 1000,
    rate_limit_per_minute: 60
  },
  {
    channel_type: 'push',
    enabled: true,
    priority: 2,
    retry_attempts: 2,
    retry_delay: 5,
    daily_limit: 2000,
    rate_limit_per_minute: 120
  },
  {
    channel_type: 'telegram',
    enabled: true,
    priority: 3,
    retry_attempts: 3,
    retry_delay: 10,
    daily_limit: 1500,
    rate_limit_per_minute: 100
  }
]

channels_data.each do |channel_data|
  channel_setting = NotificationChannelSetting.find_or_initialize_by(
    channel_type: channel_data[:channel_type]
  )
  
  if channel_setting.persisted?
    puts "  ✅ Настройки канала #{channel_data[:channel_type]} уже существуют"
  else
    channel_setting.assign_attributes(channel_data)
    channel_setting.save!
    puts "  ✅ Настройки канала #{channel_data[:channel_type]} созданы"
  end
end

puts ""
puts "🎉 Настройки системы уведомлений успешно созданы!"
puts ""
puts "📊 СТАТИСТИКА:"
puts "  📧 Email настройки: #{EmailSetting.count}"
puts "  📱 Telegram настройки: #{TelegramSetting.count}"
puts "  📲 Push настройки: #{PushSetting.count}"
puts "  🔑 Google OAuth настройки: #{GoogleOauthSetting.count}"
puts "  📋 Настройки каналов: #{NotificationChannelSetting.count}"
puts ""
puts "✅ Все настройки готовы к использованию!" 