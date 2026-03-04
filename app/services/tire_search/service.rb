# frozen_string_literal: true

module TireSearch
  # Service - главный оркестратор для поиска шин
  # Композирует QueryBuilder, ResultProcessor, CompatibilityCalculator, SuggestionEngine
  #
  # Phase-02: Redis caching for AI search queries
  #   - LLM parsing results cached with SHA256 key, 1 hour TTL
  #   - force_refresh option to bypass cache
  #   - Cache hit/miss metrics logged
  class Service
    # Константы алиасов (экспортируем для обратной совместимости)
    BRAND_ALIASES = TireSearchService::BRAND_ALIASES
    MODEL_ALIASES = TireSearchService::MODEL_ALIASES
    TIRE_BRANDS = TireSearchService::TIRE_BRANDS
    TIRE_BRAND_ALIASES = TireSearchService::TIRE_BRAND_ALIASES
    SEASONALITY_ALIASES = TireSearchService::SEASONALITY_ALIASES

    # Cache configuration
    AI_SEARCH_CACHE_TTL = 1.hour
    AI_SEARCH_CACHE_PREFIX = 'tire_search'

    attr_reader :query, :options, :parsed_data

    def initialize(query, options = {})
      @query = query.to_s.strip
      @options = options.with_indifferent_access
      @parsed_data = {}
      @locale = options[:locale] || 'ru'
      @context = options[:context] || {}
      @use_llm = options[:use_llm] != false
      @force_refresh = options[:force_refresh] == true
    end

    # Главный метод поиска
    def search
      return build_empty_response if @query.blank?

      # Шаг 1: Парсинг запроса
      parse_query

      # Шаг 2: Объединение с контекстом
      merge_with_context

      # Шаг 3: LLM парсинг (если нужен) - with Redis caching
      apply_llm_parsing if needs_llm_parsing?

      # Шаг 4: Определение сценария и обработка
      process_search_scenario
    end

    # Поиск шин по параметрам (для API)
    def search_tires(params = {})
      merged_params = @options.merge(params)

      query_builder = QueryBuilder.new(merged_params)
      scope = query_builder.build

      result_processor = ResultProcessor.new(scope, merged_params)
      result_processor.process
    end

    # Поиск по автомобилю
    def search_by_vehicle(brand:, model:, year: nil)
      calculator = CompatibilityCalculator.new(
        brand: brand,
        model: model,
        year: year
      )

      tire_sizes = calculator.find_compatible_sizes

      {
        success: tire_sizes.any?,
        vehicle: { brand: brand, model: model, year: year }.compact,
        tire_sizes: tire_sizes,
        oem_sizes: calculator.oem_sizes,
        aftermarket_sizes: calculator.aftermarket_sizes
      }
    end

    # Подсказки для автокомплита
    def suggest(query = nil)
      engine = SuggestionEngine.new(query || @query)
      engine.all_suggestions
    end

    # Вычислить совместимость размера с автомобилем
    def calculate_compatibility(tire_size, vehicle)
      calculator = CompatibilityCalculator.new(vehicle)
      {
        compatible: calculator.compatible?(tire_size),
        score: calculator.calculate_compatibility_score(tire_size)
      }
    end

    private

    def build_empty_response
      {
        success: false,
        message: I18n.t('tire_search.messages.empty_query', default: 'Запрос не может быть пустым'),
        tire_sizes: [],
        tire_brands: [],
        seasonality: nil,
        car_info: {},
        query: @query,
        parsed_data: {},
        suggestions: SuggestionEngine.new.popular_searches
      }
    end

    def parse_query
      @parsed_data = QueryParser.new(@query).parse
    rescue StandardError => e
      Rails.logger.error "TireSearch::Service parse error: #{e.message}"
      @parsed_data = {}
    end

    def merge_with_context
      return if @context.blank?

      @context.each do |key, value|
        @parsed_data[key] = value if value.present? && @parsed_data[key].blank?
      end

      # Особая логика для tire_brands - объединяем массивы
      if @context[:tire_brands].present?
        @parsed_data[:tire_brands] = (@parsed_data[:tire_brands] || []) | @context[:tire_brands]
      end
    end

    def needs_llm_parsing?
      return false unless @use_llm
      return false if full_tire_size_found? && car_identified?
      return false if full_tire_size_found? && @parsed_data[:brand].blank?

      has_potential_words? || complex_query?
    end

    def apply_llm_parsing
      return unless OpenaiService.available?

      # Try cached LLM result first (Phase-02)
      cache_key = ai_search_cache_key(@query)

      if !@force_refresh && (cached = Rails.cache.read(cache_key))
        Rails.logger.info "[TireSearch] Cache HIT for query: '#{@query.truncate(50)}' (key: #{cache_key})"
        log_cache_metric(:hit)
        @parsed_data = smart_merge_results(@parsed_data, cached)
        return
      end

      Rails.logger.info "[TireSearch] Cache MISS for query: '#{@query.truncate(50)}' (key: #{cache_key})"
      log_cache_metric(:miss)

      result = AiRequestWrapper.call(operation: 'tire_search_llm_parsing') do
        OpenaiService.new.parse_tire_search_query(@query)
      end

      if result.success? && result.data.present?
        # Cache only successful results
        Rails.cache.write(cache_key, result.data, expires_in: AI_SEARCH_CACHE_TTL)
        Rails.logger.info "[TireSearch] Cached AI result for query: '#{@query.truncate(50)}'"
        @parsed_data = smart_merge_results(@parsed_data, result.data)
      elsif result.fallback?
        Rails.logger.warn "TireSearch: AI unavailable (circuit open), using DB-only search"
      end
    end

    # Generate cache key for AI search query
    def ai_search_cache_key(query)
      normalized = query.downcase.strip
      "#{AI_SEARCH_CACHE_PREFIX}:#{Digest::SHA256.hexdigest(normalized)}"
    end

    # Track cache hit/miss metrics in Redis
    def log_cache_metric(type)
      today = Date.current.to_s
      metric_key = "tire_search_cache_metrics:#{today}"
      field = type == :hit ? 'hits' : 'misses'

      begin
        redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
        redis.hincrby(metric_key, field, 1)
        redis.expire(metric_key, 7.days.to_i) # Keep metrics for 7 days
      rescue Redis::BaseError => e
        Rails.logger.warn "[TireSearch] Failed to log cache metric: #{e.message}"
      end
    end

    def process_search_scenario
      if full_tire_size_found?
        process_tire_size_scenario
      elsif car_identified?
        process_car_scenario
      elsif @parsed_data[:brand].present? && @parsed_data[:diameter].present?
        process_brand_diameter_scenario
      elsif partial_size_found?
        process_partial_size_scenario
      else
        process_insufficient_data_scenario
      end
    end

    def process_tire_size_scenario
      tire_size = @parsed_data[:tire_size] || build_tire_size_from_params
      
      {
        success: true,
        message: I18n.t('tire_search.messages.size_found', default: 'Найден размер шин'),
        tire_sizes: [tire_size],
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: extract_car_info,
        query: @query,
        parsed_data: @parsed_data
      }
    end

    def process_car_scenario
      calculator = CompatibilityCalculator.new(
        brand: @parsed_data[:brand],
        model: @parsed_data[:model],
        year: @parsed_data[:year],
        diameter: @parsed_data[:diameter]
      )

      tire_sizes = calculator.find_compatible_sizes

      if tire_sizes.empty?
        return {
          success: false,
          message: I18n.t('tire_search.messages.no_sizes_for_car',
                         brand: @parsed_data[:brand],
                         model: @parsed_data[:model],
                         default: "Для #{@parsed_data[:brand]} #{@parsed_data[:model]} пока нет данных о размерах шин"),
          tire_sizes: [],
          tire_brands: @parsed_data[:tire_brands] || [],
          seasonality: @parsed_data[:seasonality],
          car_info: extract_car_info,
          query: @query,
          parsed_data: @parsed_data,
          suggestions: generate_car_suggestions
        }
      end

      {
        success: true,
        message: I18n.t('tire_search.messages.sizes_found_for_car',
                       brand: @parsed_data[:brand],
                       model: @parsed_data[:model],
                       default: "Найдены размеры шин для #{@parsed_data[:brand]} #{@parsed_data[:model]}"),
        tire_sizes: tire_sizes,
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: extract_car_info,
        query: @query,
        parsed_data: @parsed_data
      }
    end

    def process_brand_diameter_scenario
      engine = SuggestionEngine.new(@parsed_data[:brand])
      model_suggestions = engine.related_searches

      {
        success: false,
        conversation_mode: true,
        message: I18n.t('tire_search.messages.specify_model',
                       brand: @parsed_data[:brand],
                       diameter: @parsed_data[:diameter],
                       default: "Уточните модель #{@parsed_data[:brand]} для поиска шин R#{@parsed_data[:diameter]}"),
        tire_sizes: [{ diameter: @parsed_data[:diameter], display: "R#{@parsed_data[:diameter]}" }],
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: { brand: @parsed_data[:brand] },
        query: @query,
        parsed_data: @parsed_data,
        suggestions: model_suggestions,
        follow_up_questions: [{
          type: 'model_selection',
          brand: @parsed_data[:brand],
          field: 'model',
          diameter: @parsed_data[:diameter]
        }],
        context: build_context
      }
    end

    def process_partial_size_scenario
      {
        success: false,
        conversation_mode: true,
        message: build_partial_size_message,
        tire_sizes: [build_partial_size_display],
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: {},
        query: @query,
        parsed_data: @parsed_data,
        suggestions: SuggestionEngine.new.popular_searches,
        follow_up_questions: [build_partial_size_question],
        context: build_context
      }
    end

    def process_insufficient_data_scenario
      {
        success: false,
        conversation_mode: true,
        message: build_insufficient_data_message,
        tire_sizes: [],
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: extract_car_info,
        query: @query,
        parsed_data: @parsed_data,
        suggestions: SuggestionEngine.new.popular_searches,
        follow_up_questions: generate_follow_up_questions
      }
    end

    # === Helper methods ===

    def full_tire_size_found?
      @parsed_data[:tire_size].present? ||
        (@parsed_data[:width].present? && @parsed_data[:height].present? && @parsed_data[:diameter].present?)
    end

    def car_identified?
      @parsed_data[:brand].present? && @parsed_data[:model].present?
    end

    def partial_size_found?
      @parsed_data[:diameter].present? ||
        (@parsed_data[:width].present? && @parsed_data[:height].present?) ||
        (@parsed_data[:width].present? && @parsed_data[:diameter].present?) ||
        (@parsed_data[:height].present? && @parsed_data[:diameter].present?)
    end

    def has_potential_words?
      words = @query.downcase.split(/\s+/).reject do |w|
        w.match?(/\A\d+\z/) || w.match?(/\A(шины|резина|на|для|р|r)\z/i)
      end
      words.any? { |word| word.length >= 3 }
    end

    def complex_query?
      @query.match?(/какие|посоветуйте|подойдет|нужны|помогите|скажите|подскажите/i) ||
        @query.match?(/поменял|купил|заменил|установил|ищу|хочу/i) ||
        @query.split.length > 8
    end

    def build_tire_size_from_params
      {
        width: @parsed_data[:width],
        height: @parsed_data[:height],
        diameter: @parsed_data[:diameter],
        full_size: "#{@parsed_data[:width]}/#{@parsed_data[:height]}R#{@parsed_data[:diameter]}"
      }
    end

    def extract_car_info
      {
        brand: @parsed_data[:brand],
        model: @parsed_data[:model],
        year: @parsed_data[:year]
      }.compact
    end

    def build_context
      {
        brand: @parsed_data[:brand],
        diameter: @parsed_data[:diameter],
        width: @parsed_data[:width],
        height: @parsed_data[:height],
        tire_brands: @parsed_data[:tire_brands],
        seasonality: @parsed_data[:seasonality]
      }.compact
    end

    def build_partial_size_message
      if @parsed_data[:diameter].present? && @parsed_data[:width].blank?
        I18n.t('tire_search.messages.diameter_only',
               diameter: @parsed_data[:diameter],
               default: "Найден диаметр R#{@parsed_data[:diameter]}. Укажите полный размер шин.")
      elsif @parsed_data[:width].present? && @parsed_data[:height].present?
        I18n.t('tire_search.messages.width_height_only',
               width: @parsed_data[:width],
               height: @parsed_data[:height],
               default: "Найден частичный размер #{@parsed_data[:width]}/#{@parsed_data[:height]}. Укажите диаметр.")
      else
        I18n.t('tire_search.messages.partial_size', default: 'Укажите полный размер шин.')
      end
    end

    def build_partial_size_display
      parts = []
      parts << @parsed_data[:width] if @parsed_data[:width]
      parts << @parsed_data[:height] if @parsed_data[:height]
      display = parts.any? ? "#{parts.join('/')}R#{@parsed_data[:diameter] || '?'}" : "R#{@parsed_data[:diameter]}"

      {
        width: @parsed_data[:width],
        height: @parsed_data[:height],
        diameter: @parsed_data[:diameter],
        display: display
      }.compact
    end

    def build_partial_size_question
      missing = if @parsed_data[:diameter].blank?
                  'diameter'
                elsif @parsed_data[:width].blank?
                  'width'
                else
                  'height'
                end

      {
        type: 'partial_size_completion',
        field: missing,
        width: @parsed_data[:width],
        height: @parsed_data[:height],
        diameter: @parsed_data[:diameter]
      }.compact
    end

    def build_insufficient_data_message
      if @parsed_data[:brand].present? && @parsed_data[:model].blank?
        I18n.t('tire_search.messages.excellent_choice',
               brand: @parsed_data[:brand],
               default: "Отлично! #{@parsed_data[:brand]} - хороший выбор. Укажите модель:")
      else
        I18n.t('tire_search.messages.help_select',
               default: 'Помогу подобрать шины! Укажите марку и модель автомобиля или размер шин.')
      end
    end

    def generate_car_suggestions
      return [] unless @parsed_data[:brand].present?

      engine = SuggestionEngine.new(@parsed_data[:brand])
      engine.related_searches.first(5)
    end

    def generate_follow_up_questions
      questions = []

      if @parsed_data[:brand].blank?
        questions << {
          type: 'brand_selection',
          question: 'Какая марка автомобиля?',
          field: 'brand'
        }
      elsif @parsed_data[:model].blank?
        questions << {
          type: 'model_selection',
          question: "Какая модель #{@parsed_data[:brand]}?",
          field: 'model',
          context: { brand: @parsed_data[:brand] }
        }
      end

      if @parsed_data[:seasonality].blank?
        questions << {
          type: 'seasonality_selection',
          question: 'Какие шины нужны?',
          field: 'seasonality',
          options: [
            { value: 'winter', label: 'Зимние' },
            { value: 'summer', label: 'Летние' },
            { value: 'all_season', label: 'Всесезонные' }
          ]
        }
      end

      questions.first(2)
    end

    def smart_merge_results(simple_data, llm_data)
      result = simple_data.dup

      # LLM может обновлять brand и model
      if llm_data[:brand].present? && simple_data[:brand].blank?
        result[:brand] = llm_data[:brand]
      end

      if llm_data[:model].present? && simple_data[:model].blank?
        result[:model] = llm_data[:model]
      end

      # Для остальных полей - LLM дополняет
      llm_data.each do |key, value|
        next if %i[brand model].include?(key)

        result[key] = value if value.present? && result[key].blank?
      end

      result
    end
  end
end
