class NotificationChannelSetting < ApplicationRecord
  # Константы для типов каналов
  CHANNEL_TYPES = %w[email push telegram sms].freeze
  
  # Валидации
  validates :channel_type, presence: true, 
                          inclusion: { in: CHANNEL_TYPES, message: "должен быть одним из: #{CHANNEL_TYPES.join(', ')}" },
                          uniqueness: { message: "уже существует настройка для этого канала" }
  
  validates :priority, presence: true, 
                      numericality: { greater_than: 0, less_than_or_equal_to: 10 }
  
  validates :retry_attempts, presence: true, 
                            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  
  validates :retry_delay, presence: true, 
                         numericality: { greater_than: 0, less_than_or_equal_to: 1440 } # максимум сутки в минутах
  
  validates :daily_limit, presence: true, 
                         numericality: { greater_than: 0, less_than_or_equal_to: 100_000 }
  
  validates :rate_limit_per_minute, presence: true, 
                                   numericality: { greater_than: 0, less_than_or_equal_to: 1000 }

  # Скоупы
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :by_priority, -> { order(:priority, :created_at) }
  scope :by_channel_type, ->(type) { where(channel_type: type) }

  # Методы класса
  def self.for_channel(channel_type)
    find_by(channel_type: channel_type.to_s)
  end

  def self.enabled_channels
    enabled.pluck(:channel_type)
  end

  def self.channels_by_priority
    enabled.by_priority.pluck(:channel_type)
  end

  # Методы инстанса
  def channel_name
    case channel_type
    when 'email'
      'Email'
    when 'push'
      'Push уведомления'
    when 'telegram'
      'Telegram'
    when 'sms'
      'SMS'
    else
      channel_type.humanize
    end
  end

  def status_text
    enabled? ? 'Активен' : 'Отключен'
  end

  def status_color
    enabled? ? 'success' : 'error'
  end

  def priority_text
    case priority
    when 1
      'Высший'
    when 2..3
      'Высокий'
    when 4..6
      'Средний'
    when 7..10
      'Низкий'
    else
      priority.to_s
    end
  end

  # Проверка лимитов
  def within_daily_limit?(current_count)
    current_count < daily_limit
  end

  def within_rate_limit?(current_count_per_minute)
    current_count_per_minute < rate_limit_per_minute
  end

  # Конфигурация для интеграции с системами отправки
  def to_config
    {
      channel_type: channel_type,
      enabled: enabled,
      priority: priority,
      retry_config: {
        attempts: retry_attempts,
        delay: retry_delay
      },
      limits: {
        daily: daily_limit,
        per_minute: rate_limit_per_minute
      }
    }
  end
end
