# frozen_string_literal: true

class OpenaiService
  TIRE_SEARCH_PROMPT = <<~PROMPT
    Ты - эксперт по автомобильным шинам. Твоя задача - извлечь из пользовательского запроса следующие параметры:

    1. **Бренд автомобиля** - основные категории:
       - Европейские: BMW, Mercedes, Audi, Volkswagen, Volvo
       - Японские: Toyota, Honda, Mazda, Nissan
       - Американские: Ford, Chevrolet, Cadillac
       - Китайские: BYD, Geely, Chery, Brilliance
       - Корейские: Hyundai, Kia

    2. **Модель автомобиля** - любые буквенно-цифровые обозначения
       - ВАЖНО: "тильда" или "тилда" = "Tiida" (Nissan Tiida)
       - "приора" = "Priora", "калина" = "Kalina", "гранта" = "Granta"

    3. **Год выпуска** (2015-2025)
    4. **Размер шин** (ширина/высота/диаметр, например 225/50R17)
    5. **Производители шин** (Michelin, Continental, Bridgestone, Pirelli и т.д.)
    6. **Сезонность** (зимние, летние, всесезонные)

    Отвечай СТРОГО в JSON формате:
    {
      "brand": "BYD",
      "model": "Dolphin", 
      "year": 2023,
      "tire_size": {
        "width": 195,
        "height": 60,
        "diameter": 16,
        "full_size": "195/60R16"
      },
      "tire_brands": ["Michelin"],
      "seasonality": "summer"
    }

    ВАЖНЫЕ ПРАВИЛА:
    - ПРИОРИТЕТ: сначала ищи бренд и модель АВТОМОБИЛЯ, потом производителя шин
    - Если слово может быть и автомобилем и шиной - это АВТОМОБИЛЬ
    - Если параметр не найден, не включай его в ответ
    - Используй стандартные английские названия брендов
    - Размер шин указывай в стандартном формате
    - Сезонность: "winter", "summer", "all_season"
    - Отвечай только JSON, без дополнительного текста

    Запрос пользователя:
  PROMPT

  TIRE_CHAT_SYSTEM_PROMPT_RU = <<~PROMPT
    Ты - эксперт-консультант по автомобильным шинам в интернет-магазине шин. 
    
    Твоя роль:
    - Отвечай профессионально и дружелюбно
    - Давай экспертные советы по выбору шин
    - Сравнивай модели объективно, указывая плюсы и минусы
    - Объясняй технические особенности простым языком
    - Учитывай специфику украинского рынка шин
    
    Правила ответов:
    - Максимум 300-400 слов
    - Используй эмодзи для лучшего восприятия (но умеренно)
    - Структурируй ответ с заголовками
    - Завершай вопросом или предложением помощи
    - Говори на русском языке
    
    Специализация:
    - Сравнение конкретных моделей шин
    - Технические характеристики
    - Рекомендации по сезонности
    - Соотношение цена/качество
    - Особенности эксплуатации
  PROMPT

  # Cache configuration for tire search queries
  TIRE_SEARCH_CACHE_TTL = 24.hours
  TIRE_SEARCH_CACHE_PREFIX = 'tire_search_llm'

  TIRE_CHAT_SYSTEM_PROMPT_UK = <<~PROMPT
    Ти - експерт-консультант з автомобільних шин в інтернет-магазині шин.
    
    Твоя роль:
    - Відповідай професійно та дружньо
    - Давай експертні поради щодо вибору шин
    - Порівнюй моделі об'єктивно, вказуючи плюси та мінуси
    - Пояснюй технічні особливості простою мовою
    - Враховуй специфіку українського ринку шин
    
    Правила відповідей:
    - Максимум 300-400 слів
    - Використовуй емодзі для кращого сприйняття (але помірно)
    - Структуруй відповідь із заголовками
    - Завершуй питанням або пропозицією допомоги
    - Говори українською мовою
    
    Спеціалізація:
    - Порівняння конкретних моделей шин
    - Технічні характеристики
    - Рекомендації щодо сезонності
    - Співвідношення ціна/якість
    - Особливості експлуатації
  PROMPT

  def initialize
    @client = setup_client
  end

  # Универсальный метод для chat completion
  def chat_completion(prompt, options = {})
    return nil unless @client && prompt.present?

    begin
      response = @client.chat(
        parameters: {
          model: options[:model] || openai_model,
          messages: [
            {
              role: "user",
              content: prompt
            }
          ],
          max_tokens: options[:max_tokens] || openai_max_tokens,
          temperature: options[:temperature] || openai_temperature
        }
      )

      Rails.logger.info "🤖 OpenAI chat completion response received"
      response
    rescue => e
      Rails.logger.error "❌ OpenAI chat completion error: #{e.message}"
      nil
    end
  end

  def parse_tire_search_query(query)
    return {} unless @client && query.present?

    # Check cache first
    cache_key = tire_search_cache_key(query)
    cached_result = read_from_cache(cache_key)

    if cached_result.present?
      record_cache_hit
      Rails.logger.info "🎯 Cache HIT for tire search query: #{query[0..50]}..."
      return cached_result
    end

    record_cache_miss
    Rails.logger.info "❌ Cache MISS for tire search query: #{query[0..50]}..."

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
      Rails.logger.info "🔍 OpenAI raw response: #{content}"
      return {} unless content

      # Очищаем markdown обертку если есть
      json_content = content.strip
      if json_content.start_with?('```json') && json_content.end_with?('```')
        json_content = json_content.gsub(/\A```json\n?/, '').gsub(/\n?```\z/, '')
      elsif json_content.start_with?('```') && json_content.end_with?('```')
        json_content = json_content.gsub(/\A```\n?/, '').gsub(/\n?```\z/, '')
      end

      # Парсим JSON ответ
      result = JSON.parse(json_content)
      Rails.logger.info "🔍 OpenAI parsed JSON: #{result.inspect}"

      # Валидируем и очищаем результат
      cleaned_result = validate_and_clean_result(result)
      Rails.logger.info "🔍 OpenAI cleaned result: #{cleaned_result.inspect}"

      # Cache the result
      write_to_cache(cache_key, cleaned_result)

      cleaned_result

    rescue JSON::ParserError => e
      Rails.logger.error "OpenAI JSON parse error: #{e.message}"
      Rails.logger.error "Raw content: #{content}"
      {}
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      {}
    end
  end

  # Генерация ответа для чата о шинах
  def generate_tire_chat_response(message, current_filters = {}, locale = 'ru')
    return nil unless @client && message.present?

    begin
      # Определяем язык для промпта
      system_prompt = locale == 'uk' ? TIRE_CHAT_SYSTEM_PROMPT_UK : TIRE_CHAT_SYSTEM_PROMPT_RU
      
      # Формируем контекст с текущими фильтрами
      context = ""
      if current_filters.present?
        context_label = locale == 'uk' ? "Поточний контекст бесіди:" : "Текущий контекст беседы:"
        context = "\n\n#{context_label}\n"
        current_filters.each do |key, value|
          next if value.blank?
          context += "- #{key}: #{value}\n"
        end
      end

      response = @client.chat(
        parameters: {
          model: openai_model,
          messages: [
            {
              role: "system",
              content: system_prompt
            },
            {
              role: "user", 
              content: "#{message}#{context}"
            }
          ],
          max_tokens: 800, # Больше токенов для развернутых ответов
          temperature: 0.7  # Более творческие ответы для чата
        }
      )

      content = response.dig("choices", 0, "message", "content")
      Rails.logger.info "🤖 OpenAI chat response: #{content}"
      
      return content&.strip
      
    rescue => e
      Rails.logger.error "OpenAI chat error: #{e.message}"
      nil
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

      # Если есть все три параметра - создаем полный размер
      if width >= 145 && width <= 335 && 
         height >= 25 && height <= 85 && 
         diameter >= 13 && diameter <= 24
        
        cleaned[:tire_size] = {
          width: width,
          height: height,
          diameter: diameter,
          full_size: "#{width}/#{height}R#{diameter}"
        }
      else
        # Сохраняем отдельные параметры если они валидны
        cleaned[:width] = width if width >= 145 && width <= 335
        cleaned[:height] = height if height >= 25 && height <= 85
        cleaned[:diameter] = diameter if diameter >= 13 && diameter <= 24
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

  # Cache key generation for tire search queries
  def tire_search_cache_key(query)
    # Normalize query for better cache hits
    normalized_query = query.to_s.strip.downcase.gsub(/\s+/, ' ')
    "#{TIRE_SEARCH_CACHE_PREFIX}:#{Digest::MD5.hexdigest(normalized_query)}"
  end

  # Read from cache (supports both Redis and Rails.cache)
  def read_from_cache(cache_key)
    begin
      if Rails.cache.respond_to?(:redis) && Rails.cache.redis
        cached_json = Rails.cache.redis.get(cache_key)
        return JSON.parse(cached_json, symbolize_names: true) if cached_json
      else
        return Rails.cache.read(cache_key)
      end
    rescue => e
      Rails.logger.error "Cache read error: #{e.message}"
    end
    nil
  end

  # Write to cache with TTL
  def write_to_cache(cache_key, result)
    return if result.blank?

    begin
      if Rails.cache.respond_to?(:redis) && Rails.cache.redis
        Rails.cache.redis.setex(cache_key, TIRE_SEARCH_CACHE_TTL.to_i, result.to_json)
      else
        Rails.cache.write(cache_key, result, expires_in: TIRE_SEARCH_CACHE_TTL)
      end
      Rails.logger.info "💾 Cached tire search result for #{TIRE_SEARCH_CACHE_TTL.inspect}"
    rescue => e
      Rails.logger.error "Cache write error: #{e.message}"
    end
  end

  # Record cache hit for metrics
  def record_cache_hit
    begin
      if Rails.cache.respond_to?(:redis) && Rails.cache.redis
        Rails.cache.redis.incr("#{TIRE_SEARCH_CACHE_PREFIX}:hits")
      end
    rescue => e
      Rails.logger.debug "Failed to record cache hit: #{e.message}"
    end
  end

  # Record cache miss for metrics
  def record_cache_miss
    begin
      if Rails.cache.respond_to?(:redis) && Rails.cache.redis
        Rails.cache.redis.incr("#{TIRE_SEARCH_CACHE_PREFIX}:misses")
      end
    rescue => e
      Rails.logger.debug "Failed to record cache miss: #{e.message}"
    end
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

  # Get cache hit rate statistics
  def self.cache_stats
    begin
      if Rails.cache.respond_to?(:redis) && Rails.cache.redis
        hits = Rails.cache.redis.get("#{TIRE_SEARCH_CACHE_PREFIX}:hits").to_i
        misses = Rails.cache.redis.get("#{TIRE_SEARCH_CACHE_PREFIX}:misses").to_i
        total = hits + misses

        return {
          hits: hits,
          misses: misses,
          total: total,
          hit_rate: total > 0 ? (hits.to_f / total * 100).round(2) : 0.0,
          hit_rate_formatted: total > 0 ? "#{(hits.to_f / total * 100).round(2)}%" : "N/A"
        }
      end
    rescue => e
      Rails.logger.error "Failed to get cache stats: #{e.message}"
    end

    { hits: 0, misses: 0, total: 0, hit_rate: 0.0, hit_rate_formatted: "N/A" }
  end

  # Clear cache statistics (for testing)
  def self.reset_cache_stats
    begin
      if Rails.cache.respond_to?(:redis) && Rails.cache.redis
        Rails.cache.redis.del("#{TIRE_SEARCH_CACHE_PREFIX}:hits")
        Rails.cache.redis.del("#{TIRE_SEARCH_CACHE_PREFIX}:misses")
        return true
      end
    rescue => e
      Rails.logger.error "Failed to reset cache stats: #{e.message}"
    end
    false
  end
end