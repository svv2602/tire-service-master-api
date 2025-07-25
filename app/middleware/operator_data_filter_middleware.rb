class OperatorDataFilterMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Применяем фильтрацию только к API запросам
    if api_request?(request)
      apply_operator_filtering(request)
    end
    
    @app.call(env)
  end

  private

  def api_request?(request)
    request.path.start_with?('/api/')
  end

  def apply_operator_filtering(request)
    # Получаем текущего пользователя из сессии или токена
    current_user = extract_current_user(request)
    return unless current_user&.operator?

    # Получаем ID сервисных точек, к которым привязан оператор
    operator = current_user.operator
    service_point_ids = operator.service_points.active.pluck(:id)
    
    return if service_point_ids.empty?

    # Автоматически добавляем фильтрацию по сервисным точкам
    case request.path
    when %r{/api/v1/bookings}
      add_service_points_filter(request, 'service_point_id', service_point_ids)
    when %r{/api/v1/clients}
      # Клиенты фильтруются через бронирования
      add_service_points_filter(request, 'service_point_ids', service_point_ids)
    when %r{/api/v1/reviews}
      add_service_points_filter(request, 'service_point_id', service_point_ids)
    when %r{/api/v1/service_points}
      add_service_points_filter(request, 'id', service_point_ids)
    end
  end

  def extract_current_user(request)
    # Попытка извлечь пользователя из JWT токена
    auth_header = request.headers['Authorization']
    return nil unless auth_header&.start_with?('Bearer ')

    token = auth_header.split(' ').last
    return nil unless token

    begin
      decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' })
      user_id = decoded_token[0]['user_id']
      User.find_by(id: user_id)
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end
  end

  def add_service_points_filter(request, param_name, service_point_ids)
    # Добавляем параметр фильтрации в query string
    params = Rack::Utils.parse_query(request.query_string)
    
    # Если параметр уже существует, пересекаем с разрешенными точками
    if params.key?(param_name)
      existing_ids = Array(params[param_name]).map(&:to_i)
      filtered_ids = existing_ids & service_point_ids
      params[param_name] = filtered_ids.join(',')
    else
      params[param_name] = service_point_ids.join(',')
    end
    
    # Обновляем query string
    request.set_header('QUERY_STRING', Rack::Utils.build_query(params))
  end
end 