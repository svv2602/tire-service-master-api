# frozen_string_literal: true

# Модель для системных настроек
class SystemSetting < ApplicationRecord
  # Валидации
  validates :key, presence: true, uniqueness: true
  validates :setting_type, inclusion: { in: %w[string integer float boolean password select text] }
  validates :category, presence: true

  # Скоупы
  scope :by_category, ->(category) { where(category: category) }
  scope :by_type, ->(type) { where(setting_type: type) }
  scope :encrypted, -> { where(is_encrypted: true) }
  
  # Методы для работы с зашифрованными значениями
  before_save :encrypt_sensitive_data
  after_find :decrypt_sensitive_data

  # Получить значение настройки с типизацией
  def typed_value
    return nil if value.blank?
    
    case setting_type
    when 'integer'
      value.to_i
    when 'float'
      value.to_f
    when 'boolean'
      %w[true 1 yes on].include?(value.to_s.downcase)
    when 'password'
      is_encrypted? ? decrypt_value(value) : value
    else
      value
    end
  end

  # Установить значение с автоматической типизацией
  def typed_value=(new_value)
    self.value = case setting_type
                 when 'boolean'
                   new_value.to_s
                 else
                   new_value.to_s
                 end
  end

  # Проверка является ли настройка чувствительной (пароль, ключ API)
  def sensitive?
    setting_type == 'password' || key.include?('api_key') || key.include?('secret')
  end

  # Класс-методы для удобного доступа к настройкам
  class << self
    # Получить значение настройки
    def get_value(key, default = nil)
      setting = find_by(key: key)
      setting&.typed_value || default
    end

    # Установить значение настройки
    def set_value(key, value, options = {})
      setting = find_or_initialize_by(key: key)
      setting.typed_value = value
      setting.description = options[:description] if options[:description]
      setting.category = options[:category] if options[:category]
      setting.setting_type = options[:type] if options[:type]
      setting.updated_by = options[:updated_by] if options[:updated_by]
      setting.save!
      setting
    end

    # Получить все настройки по категории
    def get_category_settings(category)
      by_category(category).pluck(:key, :value).to_h
    end

    # Сбросить настройки к значениям по умолчанию
    def reset_to_defaults(category = nil)
      scope = category ? by_category(category) : all
      scope.find_each do |setting|
        if setting.default_value.present?
          setting.update!(value: setting.default_value)
        end
      end
    end
  end

  private

  # Шифрование чувствительных данных
  def encrypt_sensitive_data
    if sensitive? && value.present? && !is_encrypted?
      self.value = encrypt_value(value)
      self.is_encrypted = true
    end
  end

  # Расшифровка чувствительных данных
  def decrypt_sensitive_data
    # Для демонстрации - в продакшене использовать Rails.application.credentials или gem 'attr_encrypted'
    # В данном случае оставляем как есть для простоты
  end

  # Простое шифрование (в продакшене заменить на proper encryption)
  def encrypt_value(plain_value)
    # Для демонстрации - простое base64 кодирование
    # В продакшене использовать Rails.application.credentials.secret_key_base
    Base64.encode64(plain_value.to_s).strip.force_encoding('UTF-8')
  end

  # Простая расшифровка
  def decrypt_value(encrypted_value)
    Base64.decode64(encrypted_value.to_s).force_encoding('UTF-8')
  rescue => e
    Rails.logger.error "Decrypt error: #{e.message}"
    encrypted_value.to_s.force_encoding('UTF-8') # Fallback если расшифровка не удалась
  end
end