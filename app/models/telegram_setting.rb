class TelegramSetting < ApplicationRecord
  # Валидации
  validates :bot_token, format: { 
    with: /\A\d+:[A-Za-z0-9_-]+\z/, 
    message: "должен быть в формате: 123456789:ABCDEFghijklmnop",
    allow_blank: true
  }
  validates :webhook_url, format: { 
    with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), 
    message: "должен быть корректным URL",
    allow_blank: true
  }
  validates :admin_chat_id, format: { 
    with: /\A-?\d+\z/, 
    message: "должен содержать только цифры (может начинаться с -)",
    allow_blank: true
  }
  
  # Callbacks
  after_update :update_telegram_webhook, if: :saved_change_to_webhook_url?
  
  # Singleton pattern - только одна запись настроек
  def self.current
    first || create!(
      enabled: false,
      test_mode: false,
      auto_subscription: true
    )
  end
  
  # Проверка готовности к работе
  def ready_for_production?
    enabled? && bot_token.present? && webhook_url.present?
  end
  
  # Проверка конфигурации
  def valid_configuration?
    bot_token.present? && 
    bot_token.match?(/\A\d+:[A-Za-z0-9_-]+\z/) &&
    (webhook_url.blank? || webhook_url.match?(URI::DEFAULT_PARSER.make_regexp(%w[http https])))
  end
  
  # Получение токена для использования в TelegramService
  def effective_bot_token
    bot_token.presence || ENV['TELEGRAM_BOT_TOKEN']
  end
  
  # Получение webhook URL
  def effective_webhook_url
    webhook_url.presence || ENV['TELEGRAM_WEBHOOK_URL']
  end
  
  # Получение admin chat ID
  def effective_admin_chat_id
    admin_chat_id.presence || ENV['TELEGRAM_ADMIN_CHAT_ID']
  end
  
  # Статус системы
  def system_status
    return 'disabled' unless enabled?
    return 'misconfigured' unless valid_configuration?
    return 'test_mode' if test_mode?
    return 'production' if ready_for_production?
    'configured'
  end
  
  # Цвет статуса для UI
  def status_color
    case system_status
    when 'production' then 'success'
    when 'test_mode' then 'warning'
    when 'configured' then 'info'
    when 'misconfigured' then 'error'
    when 'disabled' then 'default'
    else 'default'
    end
  end
  
  # Текст статуса
  def status_text
    case system_status
    when 'production' then 'Продакшн'
    when 'test_mode' then 'Тестовый режим'
    when 'configured' then 'Настроен'
    when 'misconfigured' then 'Неправильная конфигурация'
    when 'disabled' then 'Отключен'
    else 'Неизвестно'
    end
  end
  
  # ✅ НОВЫЙ МЕТОД: Принудительное обновление webhook (обход защиты)
  def force_update_webhook!
    return unless enabled? && webhook_url.present?
    
    Rails.logger.info "🔧 Принудительное обновление webhook: #{webhook_url}"
    
    begin
      telegram_service = TelegramService.new
      response = telegram_service.set_webhook(webhook_url)
      
      if response[:ok]
        Rails.logger.info "✅ Webhook принудительно обновлен: #{webhook_url}"
        update_column(:webhook_last_updated_at, Time.current)
        { success: true, message: 'Webhook успешно обновлен' }
      else
        error_msg = "Ошибка обновления webhook: #{response[:description]}"
        Rails.logger.error "❌ #{error_msg}"
        { success: false, message: error_msg, details: response }
      end
    rescue => e
      error_msg = "Исключение при обновлении webhook: #{e.message}"
      Rails.logger.error "❌ #{error_msg}"
      { success: false, message: error_msg, error: e }
    end
  end

  private

  # Обновление webhook в Telegram API
  def update_telegram_webhook
    return unless enabled? && webhook_url.present?
    
    # ✅ ОПТИМИЗАЦИЯ: Защита от частых обновлений (rate limiting)
    if webhook_recently_updated?
      Rails.logger.info "⏳ Webhook обновление пропущено - недавно обновлялся (#{webhook_last_updated_at})"
      return
    end
    
    begin
      telegram_service = TelegramService.new
      response = telegram_service.set_webhook(webhook_url)
      
      if response[:ok]
        Rails.logger.info "✅ Webhook обновлен: #{webhook_url}"
        # Сохраняем время последнего успешного обновления
        update_column(:webhook_last_updated_at, Time.current)
      else
        Rails.logger.error "❌ Ошибка обновления webhook: #{response[:description]}"
        Rails.logger.error "❌ Код ошибки: #{response[:error_code]}" if response[:error_code]
        Rails.logger.error "❌ Полный ответ: #{response.inspect}"
      end
    rescue => e
      Rails.logger.error "❌ Исключение при обновлении webhook: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join('\n')}"
    end
  end

  private

  # ✅ ЗАЩИТА: Проверка частоты обновлений (1 минута)
  def webhook_recently_updated?
    webhook_last_updated_at.present? && webhook_last_updated_at > 1.minute.ago
  end
end
