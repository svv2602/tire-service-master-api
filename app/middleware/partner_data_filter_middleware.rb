class PartnerDataFilterMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Применяем фильтрацию только к API запросам
    if api_request?(request)
      apply_partner_filtering(request)
    end
    
    @app.call(env)
  end

  private

  def api_request?(request)
    request.path.start_with?('/api/')
  end

  def apply_partner_filtering(request)
    # Получаем текущего пользователя из сессии или токена
    current_user = extract_current_user(request)
    return unless current_user&.partner?

    # Добавляем параметр фильтрации для партнера
    partner_id = current_user.partner.id
    
    # Автоматически добавляем partner_id в параметры запроса для фильтрации
    case request.path
    when %r{/api/v1/clients}
      add_partner_filter(request, 'partner_id', partner_id)
    when %r{/api/v1/bookings}
      add_partner_filter(request, 'partner_id', partner_id)
    when %r{/api/v1/reviews}
      add_partner_filter(request, 'partner_id', partner_id)
    when %r{/api/v1/service_points}
      add_partner_filter(request, 'partner_id', partner_id)
    when %r{/api/v1/operators}
      add_partner_filter(request, 'partner_id', partner_id)
    end
  end

  def extract_current_user(request)
    # Попытка извлечь пользователя из JWT токена
    auth_header = request.headers['Authorization']
    return nil unless auth_header&.start_with?('Bearer ')

    token = auth_header.split(' ').last
    return nil unless token

    begin
      decoded_token = JWT.decode(token, Auth::JsonWebToken.secret_key, true, { algorithm: 'HS256' })
      user_id = decoded_token[0]['user_id']
      User.find_by(id: user_id)
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end
  end

  def add_partner_filter(request, param_name, partner_id)
    # Добавляем параметр фильтрации в query string
    params = Rack::Utils.parse_query(request.query_string)
    params[param_name] = partner_id.to_s unless params.key?(param_name)
    
    # Обновляем query string
    request.set_header('QUERY_STRING', Rack::Utils.build_query(params))
  end
end 