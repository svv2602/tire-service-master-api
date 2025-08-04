# frozen_string_literal: true

class OpenaiService
  TIRE_SEARCH_PROMPT = <<~PROMPT
    Ты - эксперт по автомобильным шинам. Твоя задача - извлечь из пользовательского запроса следующие параметры:

    1. **Бренд автомобиля** (BMW, Mercedes, Volkswagen, Toyota и т.д.)
    2. **Модель автомобиля** (3 Series, C-Class, Golf, Camry и т.д.)
    3. **Год выпуска** (2015-2025)
    4. **Размер шин** (ширина/высота/диаметр, например 225/50R17)
    5. **Производители шин** (Michelin, Continental, Bridgestone и т.д.)
    6. **Сезонность** (зимние, летние, всесезонные)

    Отвечай СТРОГО в JSON формате:
    {
      "brand": "BMW",
      "model": "3 Series", 
      "year": 2020,
      "tire_size": {
        "width": 225,
        "height": 50,
        "diameter": 17,
        "full_size": "225/50R17"
      },
      "tire_brands": ["Michelin"],
      "seasonality": "winter"
    }

    Правила:
    - Если параметр не найден, не включай его в ответ
    - Используй стандартные названия брендов (BMW, не БМВ)
    - Размер шин указывай в стандартном формате
    - Сезонность: "winter", "summer", "all_season"
    - Отвечай только JSON, без дополнительного текста

    Запрос пользователя:
  PROMPT

  def initialize
    @client = setup_client
  end

  def parse_tire_search_query(query)
    return {} unless @client && query.present?

    begin
      response = @client.chat(
        parameters: {
          model: openai_model,
          messages: [
            {
              role: "user",
              content: "#{TIRE_SEARCH_PROMPT}#{query}"
            }
          ],
          max_tokens: openai_max_tokens,
          temperature: openai_temperature
        }
      )

      content = response.dig("choices", 0, "message", "content")
      return {} unless content

      # Парсим JSON ответ
      result = JSON.parse(content)
      
      # Валидируем и очищаем результат
      validate_and_clean_result(result)
      
    rescue JSON::ParserError => e
      Rails.logger.error "OpenAI JSON parse error: #{e.message}"
      Rails.logger.error "Raw content: #{content}"
      {}
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      {}
    end
  end

  def test_connection
    return { success: false, message: 'OpenAI не настроен' } unless @client

    begin
      response = @client.chat(
        parameters: {
          model: openai_model,
          messages: [{ role: "user", content: "Тест соединения. Ответь просто: OK" }],
          max_tokens: 10
        }
      )

      if response.dig("choices", 0, "message", "content")
        { success: true, message: 'Подключение к OpenAI успешно' }
      else
        { success: false, message: 'Неожиданный ответ от OpenAI' }
      end
    rescue => e
      { success: false, message: "Ошибка OpenAI: #{e.message}" }
    end
  end

  private

  def setup_client
    api_key = openai_api_key
    return nil unless api_key.present?

    OpenAI::Client.new(
      access_token: api_key,
      request_timeout: openai_timeout
    )
  rescue => e
    Rails.logger.error "Failed to setup OpenAI client: #{e.message}"
    nil
  end

  def openai_api_key
    # Читаем напрямую из кэша/Redis
    setting_value = get_system_setting('openai_api_key')
    setting_value.presence || ENV['OPENAI_API_KEY']
  end

  def openai_model
    get_system_setting('openai_model').presence || 'gpt-4o-mini'
  end

  def openai_max_tokens
    (get_system_setting('openai_max_tokens').presence || '500').to_i
  end

  def openai_temperature
    (get_system_setting('openai_temperature').presence || '0.1').to_f
  end

  def openai_timeout
    (get_system_setting('openai_timeout').presence || '30').to_i
  end

  def llm_enabled?
    setting_value = get_system_setting('tire_search_enable_llm')
    setting_value.to_s.downcase == 'true'
  end

  # Вспомогательный метод для чтения настроек
  def get_system_setting(key)
    # Сначала читаем из базы данных (основной источник истины)
    begin
      if defined?(SystemSetting)
        db_setting = SystemSetting.find_by(key: key)
        if db_setting
          Rails.logger.debug "Found setting in DB: #{key} = #{db_setting.value}"
          return db_setting.typed_value
        end
      end
    rescue => e
      Rails.logger.error "Error reading system setting from DB #{key}: #{e.message}"
    end
    
    # Fallback к кэшу (для обратной совместимости)
    custom_key = "system_settings:custom:#{key}"
    
    begin
      if Rails.cache.respond_to?(:redis) && Rails.cache.redis
        setting_json = Rails.cache.redis.get(custom_key)
      else
        setting_json = Rails.cache.read(custom_key)
      end
      
      if setting_json
        setting_data = JSON.parse(setting_json, symbolize_names: true)
        Rails.logger.debug "Found setting in cache: #{key} = #{setting_data[:value]}"
        return setting_data[:value]
      end
    rescue => e
      Rails.logger.error "Error reading system setting from cache #{key}: #{e.message}"
    end
    
    # Fallback к дефолтным значениям
    default_values = {
      'openai_api_key' => '',
      'openai_model' => 'gpt-4o-mini',
      'openai_max_tokens' => '500',
      'openai_temperature' => '0.1',
      'openai_timeout' => '30',
      'tire_search_enable_llm' => 'false'
    }
    
    default_value = default_values[key]
    Rails.logger.debug "Using default value for #{key}: #{default_value}"
    default_value
  end

  def validate_and_clean_result(result)
    return {} unless result.is_a?(Hash)

    cleaned = {}

    # Валидация бренда
    if result['brand'].present?
      cleaned[:brand] = result['brand'].to_s.strip
    end

    # Валидация модели
    if result['model'].present?
      cleaned[:model] = result['model'].to_s.strip
    end

    # Валидация года
    if result['year'].present?
      year = result['year'].to_i
      cleaned[:year] = year if year >= 1990 && year <= 2030
    end

    # Валидация размера шин
    if result['tire_size'].is_a?(Hash)
      tire_size = result['tire_size']
      width = tire_size['width'].to_i
      height = tire_size['height'].to_i
      diameter = tire_size['diameter'].to_i

      if width >= 145 && width <= 335 && 
         height >= 25 && height <= 85 && 
         diameter >= 13 && diameter <= 24
        
        cleaned[:tire_size] = {
          width: width,
          height: height,
          diameter: diameter,
          full_size: "#{width}/#{height}R#{diameter}"
        }
      end
    end

    # Валидация производителей шин
    if result['tire_brands'].is_a?(Array)
      brands = result['tire_brands'].map(&:to_s).map(&:strip).reject(&:blank?)
      cleaned[:tire_brands] = brands if brands.any?
    end

    # Валидация сезонности
    if result['seasonality'].present?
      season = result['seasonality'].to_s.strip.downcase
      if %w[winter summer all_season].include?(season)
        cleaned[:seasonality] = season
      end
    end

    cleaned
  end

  # Проверка доступности LLM
  def self.available?
    service = new
    service.send(:llm_enabled?) && service.instance_variable_get(:@client).present?
  end

  # Быстрая проверка настроек
  def self.configured?
    service = new
    api_key = service.send(:openai_api_key)
    api_key.present?
  end
end