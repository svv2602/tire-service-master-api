class AuditContextMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Устанавливаем контекст аудита для текущего запроса
    setup_audit_context(request)
    
    # Выполняем запрос
    response = @app.call(env)
    
    # Очищаем контекст после выполнения запроса
    cleanup_audit_context
    
    response
  rescue => e
    # Очищаем контекст даже в случае ошибки
    cleanup_audit_context
    raise e
  end

  private

  def setup_audit_context(request)
    # Получаем IP адрес клиента
    ip_address = extract_client_ip(request)
    
    # Получаем User-Agent
    user_agent = request.user_agent
    
    # Генерируем уникальный ID запроса
    request_id = generate_request_id
    
    # Получаем session ID если доступен
    session_id = extract_session_id(request)
    
    # Получаем текущего пользователя из токена (если есть)
    current_user = extract_current_user(request)
    
    # Устанавливаем контекст в Thread.current
    Thread.current[:current_ip_address] = ip_address
    Thread.current[:current_user_agent] = user_agent
    Thread.current[:current_request_id] = request_id
    Thread.current[:current_session_id] = session_id
    Thread.current[:current_audit_user] = current_user
    
    # Логируем начало запроса для API endpoints
    log_request_start(request, current_user, ip_address, user_agent, request_id) if api_request?(request)
  end

  def cleanup_audit_context
    # Очищаем все audit-связанные переменные
    Thread.current[:current_ip_address] = nil
    Thread.current[:current_user_agent] = nil
    Thread.current[:current_request_id] = nil
    Thread.current[:current_session_id] = nil
    Thread.current[:current_audit_user] = nil
    Thread.current[:skip_audit] = nil
    Thread.current[:force_async_audit] = nil
  end

  def extract_client_ip(request)
    # Получаем реальный IP клиента, учитывая прокси
    request.headers['HTTP_X_REAL_IP'] ||
      request.headers['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip ||
      request.remote_ip
  end

  def extract_session_id(request)
    # Пытаемся получить session ID из cookies или headers
    request.session.id if request.session.respond_to?(:id)
  rescue
    nil
  end

  def extract_current_user(request)
    # Извлекаем пользователя из JWT токена
    auth_header = request.headers['Authorization']
    return nil unless auth_header&.start_with?('Bearer ')

    token = auth_header.split(' ').last
    return nil unless token

    begin
      decoded_token = JWT.decode(
        token, 
        Rails.application.credentials.secret_key_base, 
        true, 
        { algorithm: 'HS256' }
      )
      user_id = decoded_token[0]['user_id']
      User.find_by(id: user_id)
    rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
      nil
    end
  end

  def generate_request_id
    # Генерируем уникальный ID запроса
    SecureRandom.uuid
  end

  def api_request?(request)
    # Проверяем, является ли запрос API запросом
    request.path.start_with?('/api/')
  end

  def log_request_start(request, user, ip_address, user_agent, request_id)
    # Логируем начало API запроса для отслеживания активности
    return unless should_log_request?(request)
    
    AuditLogJob.perform_later(
      action: 'api_request',
      user_id: user&.id,
      additional_data: {
        method: request.method,
        path: request.path,
        query_params: sanitize_query_params(request.query_parameters),
        request_id: request_id,
        timestamp: Time.current
      },
      ip_address: ip_address,
      user_agent: user_agent
    )
  end

  def should_log_request?(request)
    # Определяем, нужно ли логировать данный запрос
    # Не логируем некритичные запросы для экономии места
    excluded_paths = [
      '/api/v1/health',
      '/api/v1/ping',
      '/api/v1/status'
    ]
    
    # Не логируем GET запросы к некритичным endpoints
    return false if request.get? && excluded_paths.any? { |path| request.path.start_with?(path) }
    
    # Логируем все POST, PUT, PATCH, DELETE запросы
    return true if %w[POST PUT PATCH DELETE].include?(request.method)
    
    # Логируем GET запросы к критичным endpoints
    critical_paths = [
      '/api/v1/users',
      '/api/v1/admin',
      '/api/v1/audit_logs'
    ]
    
    critical_paths.any? { |path| request.path.start_with?(path) }
  end

  def sanitize_query_params(params)
    # Убираем чувствительные данные из параметров запроса
    sensitive_keys = %w[password password_confirmation token api_key secret]
    
    params.deep_dup.tap do |sanitized|
      sensitive_keys.each do |key|
        sanitized.delete(key)
        sanitized.each_value do |value|
          if value.is_a?(Hash)
            value.delete(key)
          end
        end
      end
    end
  end
end 