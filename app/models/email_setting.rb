class EmailSetting < ApplicationRecord
  # Валидации
  validates :smtp_host, format: { 
    with: /\A[a-zA-Z0-9.-]+\z/, 
    message: "должен содержать только буквы, цифры, точки и дефисы",
    allow_blank: true
  }
  validates :smtp_port, numericality: { 
    greater_than: 0, 
    less_than: 65536,
    message: "должен быть числом от 1 до 65535"
  }, allow_blank: true
  validates :smtp_username, presence: true, if: :smtp_authentication_required?
  validates :smtp_password, presence: true, if: :smtp_authentication_required?
  validates :from_email, format: { 
    with: URI::MailTo::EMAIL_REGEXP, 
    message: "должен быть корректным email адресом"
  }, allow_blank: true
  validates :smtp_authentication, inclusion: { 
    in: %w[plain login cram_md5], 
    message: "должен быть одним из: plain, login, cram_md5"
  }, allow_blank: true

  # Singleton pattern - только одна запись настроек
  def self.current
    first || create!(
      enabled: false,
      smtp_port: 587,
      smtp_authentication: 'plain',
      smtp_starttls_auto: true,
      smtp_tls: false,
      test_mode: false,
      from_name: 'Tire Service'
    )
  end

  # Проверка готовности к работе
  def ready_for_production?
    enabled? && 
    smtp_host.present? && 
    smtp_port.present? && 
    from_email.present? &&
    (smtp_authentication.blank? || (smtp_username.present? && smtp_password.present?))
  end

  # Проверка валидности конфигурации
  def valid_configuration?
    smtp_host.present? && 
    smtp_port.present? && 
    smtp_port.between?(1, 65535) &&
    from_email.present? &&
    from_email.match?(URI::MailTo::EMAIL_REGEXP)
  end

  # Получение настроек для ActionMailer
  def to_actionmailer_config
    {
      address: smtp_host,
      port: smtp_port,
      user_name: smtp_username,
      password: smtp_password,
      authentication: smtp_authentication.presence&.to_sym,
      enable_starttls_auto: smtp_starttls_auto,
      tls: smtp_tls
    }.compact
  end

  # Эффективные настройки (БД или ENV)
  def effective_smtp_host
    smtp_host.presence || ENV['SMTP_HOST']
  end

  def effective_smtp_port
    smtp_port || ENV['SMTP_PORT']&.to_i || 587
  end

  def effective_smtp_username
    smtp_username.presence || ENV['SMTP_USERNAME']
  end

  def effective_smtp_password
    smtp_password.presence || ENV['SMTP_PASSWORD']
  end

  def effective_from_email
    from_email.presence || ENV['FROM_EMAIL']
  end

  def effective_from_name
    from_name.presence || ENV['FROM_NAME'] || 'Tire Service'
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

  private

  def smtp_authentication_required?
    smtp_authentication.present? && smtp_authentication != 'none'
  end
end 