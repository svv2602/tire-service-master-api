class GoogleOauthSetting < ApplicationRecord
  # Валидации
  validates :client_id, format: { 
    with: /\A[a-zA-Z0-9.-]+\.apps\.googleusercontent\.com\z/, 
    message: "должен быть в формате: xxxxxx.apps.googleusercontent.com",
    allow_blank: true
  }
  validates :client_secret, format: { 
    with: /\A[a-zA-Z0-9_-]+\z/, 
    message: "должен содержать только буквы, цифры, дефисы и подчеркивания",
    allow_blank: true
  }
  validates :redirect_uri, format: { 
    with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), 
    message: "должен быть корректным URL",
    allow_blank: true
  }

  # Singleton pattern - только одна запись настроек
  def self.current
    first || create!(
      enabled: false,
      allow_registration: true,
      auto_verify_email: true,
      scopes_list: 'email,profile',
      redirect_uri: 'http://localhost:3008/auth/google/callback'
    )
  end

  # Проверка готовности к работе
  def ready_for_production?
    enabled? && 
    client_id.present? && 
    client_secret.present? && 
    redirect_uri.present?
  end

  # Проверка валидности конфигурации
  def valid_configuration?
    client_id.present? && 
    client_id.match?(/\A[a-zA-Z0-9.-]+\.apps\.googleusercontent\.com\z/) &&
    client_secret.present? &&
    redirect_uri.present? &&
    redirect_uri.match?(URI::DEFAULT_PARSER.make_regexp(%w[http https]))
  end

  # Получение списка скоупов
  def scopes_array
    return ['email', 'profile'] if scopes_list.blank?
    scopes_list.split(',').map(&:strip)
  end

  def scopes_array=(array)
    self.scopes_list = array.join(',')
  end

  # Эффективные настройки (БД или ENV)
  def effective_client_id
    client_id.presence || ENV['GOOGLE_CLIENT_ID']
  end

  def effective_client_secret
    client_secret.presence || ENV['GOOGLE_CLIENT_SECRET']
  end

  def effective_redirect_uri
    redirect_uri.presence || ENV['GOOGLE_REDIRECT_URI']
  end

  # Статус системы
  def system_status
    return 'disabled' unless enabled?
    return 'misconfigured' unless valid_configuration?
    return 'production' if ready_for_production?
    'configured'
  end

  # Цвет статуса для UI
  def status_color
    case system_status
    when 'production' then 'success'
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
    when 'configured' then 'Настроен'
    when 'misconfigured' then 'Неправильная конфигурация'
    when 'disabled' then 'Отключен'
    else 'Неизвестно'
    end
  end

  # Генерация URL для авторизации
  def authorization_url(state = nil)
    return nil unless valid_configuration?
    
    params = {
      client_id: effective_client_id,
      redirect_uri: effective_redirect_uri,
      scope: scopes_array.join(' '),
      response_type: 'code',
      access_type: 'offline',
      prompt: 'consent'
    }
    params[:state] = state if state.present?
    
    query_string = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
    "https://accounts.google.com/o/oauth2/auth?#{query_string}"
  end
end 