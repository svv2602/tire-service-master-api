class PushSetting < ApplicationRecord
  # Валидации
  validates :vapid_public_key, format: { 
    with: /\A[A-Za-z0-9_-]{87}=\z/, 
    message: "должен быть в формате Base64 (88 символов)",
    allow_blank: true
  }
  validates :vapid_private_key, format: { 
    with: /\A[A-Za-z0-9_-]{42}=\z/, 
    message: "должен быть в формате Base64 (43 символа)",
    allow_blank: true
  }
  validates :daily_limit, presence: true, numericality: { greater_than: 0 }
  validates :rate_limit, presence: true, numericality: { greater_than: 0 }
  
  # Singleton pattern - только одна запись настроек
  def self.current
    first || create!(
      enabled: false,
      test_mode: false,
      daily_limit: 1000,
      rate_limit: 100
    )
  end
  
  # Проверка готовности к работе
  def ready_for_production?
    enabled? && vapid_public_key.present? && vapid_private_key.present?
  end
  
  # Проверка конфигурации
  def valid_configuration?
    vapid_public_key.present? && 
    vapid_private_key.present? &&
    vapid_public_key.match?(/\A[A-Za-z0-9_-]{87}=\z/) &&
    vapid_private_key.match?(/\A[A-Za-z0-9_-]{42}=\z/)
  end
  
  # Получение VAPID ключей для использования в PushService
  def effective_vapid_public_key
    vapid_public_key.presence || ENV['VAPID_PUBLIC_KEY']
  end
  
  def effective_vapid_private_key
    vapid_private_key.presence || ENV['VAPID_PRIVATE_KEY']
  end
  
  # Получение Firebase настроек
  def effective_firebase_api_key
    firebase_api_key.presence || ENV['FIREBASE_API_KEY']
  end
  
  def effective_firebase_project_id
    firebase_project_id.presence || ENV['FIREBASE_PROJECT_ID']
  end
  
  def effective_firebase_app_id
    firebase_app_id.presence || ENV['FIREBASE_APP_ID']
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
  
  # Проверка лимитов
  def within_daily_limit?(current_count = 0)
    current_count < daily_limit
  end
  
  def within_rate_limit?(current_rate = 0)
    current_rate < rate_limit
  end
  
  # Маскирование ключей для безопасного отображения
  def masked_vapid_public_key
    return nil unless vapid_public_key.present?
    "#{vapid_public_key[0..10]}...#{vapid_public_key[-10..-1]}"
  end
  
  def masked_vapid_private_key
    return nil unless vapid_private_key.present?
    "#{vapid_private_key[0..6]}...#{vapid_private_key[-6..-1]}"
  end
end 