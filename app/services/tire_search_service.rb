class TireSearchService
  # Константы алиасов для брендов
  BRAND_ALIASES = {
    ['bmw', 'бмв', 'бэмв', 'бмдабльвэ'] => 'BMW',
    ['volkswagen', 'vw', 'фольксваген', 'фольц', 'вольксваген'] => 'Volkswagen',
    ['mercedes', 'мерседес', 'мерс', 'mercedes-benz', 'мерседес-бенц'] => 'Mercedes-Benz',
    ['toyota', 'тойота'] => 'Toyota',
    ['honda', 'хонда'] => 'Honda',
    ['audi', 'ауди'] => 'Audi',
    ['ford', 'форд'] => 'Ford',
    ['opel', 'опель'] => 'Opel',
    ['renault', 'рено'] => 'Renault',
    ['peugeot', 'пежо'] => 'Peugeot',
    ['citroen', 'ситроен'] => 'Citroen',
    ['nissan', 'ниссан'] => 'Nissan',
    ['mazda', 'мазда'] => 'Mazda',
    ['hyundai', 'хундай', 'хёндай'] => 'Hyundai',
    ['kia', 'киа'] => 'Kia',
    ['skoda', 'шкода'] => 'Skoda',
    ['seat', 'сеат'] => 'SEAT',
    ['fiat', 'фиат'] => 'Fiat',
    ['volvo', 'вольво'] => 'Volvo',
    ['mitsubishi', 'митсубиси'] => 'Mitsubishi'
  }.freeze

  # Константы алиасов для моделей по брендам
  MODEL_ALIASES = {
    'BMW' => {
      ['3', '320', '330', 'тройка', '3 series', 'третья серия'] => '3 Series',
      ['5', '520', '530', 'пятерка', '5 series', 'пятая серия'] => '5 Series',
      ['7', '730', '740', 'семерка', '7 series', 'седьмая серия'] => '7 Series',
      ['x3', 'икс3', 'x 3'] => 'X3',
      ['x5', 'икс5', 'x 5'] => 'X5',
      ['x1', 'икс1', 'x 1'] => 'X1'
    },
    'Volkswagen' => {
      ['tiguan', 'тигуан'] => 'Tiguan',
      ['golf', 'гольф'] => 'Golf',
      ['passat', 'пассат'] => 'Passat',
      ['polo', 'поло'] => 'Polo',
      ['touareg', 'туарег'] => 'Touareg',
      ['jetta', 'джетта'] => 'Jetta'
    },
    'Mercedes-Benz' => {
      ['c class', 'c-class', 'с класс', 'c200', 'c220'] => 'C-Class',
      ['e class', 'e-class', 'е класс', 'e200', 'e220'] => 'E-Class',
      ['s class', 's-class', 'с класс', 's500'] => 'S-Class',
      ['glc', 'глс'] => 'GLC',
      ['gle', 'гле'] => 'GLE'
    },
    'Toyota' => {
      ['camry', 'камри'] => 'Camry',
      ['corolla', 'корола'] => 'Corolla',
      ['rav4', 'рав4', 'rav 4'] => 'RAV4',
      ['land cruiser', 'ленд крузер', 'крузер'] => 'Land Cruiser',
      ['prius', 'приус'] => 'Prius'
    },
    'Honda' => {
      ['civic', 'цивик'] => 'Civic',
      ['accord', 'аккорд'] => 'Accord',
      ['cr-v', 'crv', 'цр-в'] => 'CR-V'
    }
  }.freeze

  def initialize(query, options = {})
    @query = query.to_s.strip
    @options = options
    @parsed_data = {}
    @use_llm = options[:use_llm] != false
  end

  def search
    return { results: [], query: @query, parsed_data: {}, total: 0 } if @query.blank?

    # Шаг 1: Простой парсинг
    @parsed_data = parse_simple_query

    # Шаг 2: Если простой парсинг неполный и включен LLM - используем LLM
    if needs_llm_parsing? && @use_llm
      llm_result = parse_with_llm
      @parsed_data = @parsed_data.merge(llm_result) if llm_result.present?
    end

    # Шаг 3: Поиск в базе данных
    results = search_configurations

    # Шаг 4: Форматирование результатов
    formatted_results = format_results(results)

    {
      results: formatted_results,
      query: @query,
      parsed_data: @parsed_data,
      total: results.size,
      suggestions: generate_suggestions
    }
  end

  private

  def parse_simple_query
    result = {}
    query_lower = @query.downcase

    # Поиск бренда
    BRAND_ALIASES.each do |aliases, brand_name|
      if aliases.any? { |alias_name| query_lower.include?(alias_name) }
        result[:brand] = brand_name
        break
      end
    end

    # Поиск модели (если найден бренд)
    if result[:brand] && MODEL_ALIASES[result[:brand]]
      MODEL_ALIASES[result[:brand]].each do |aliases, model_name|
        if aliases.any? { |alias_name| query_lower.include?(alias_name) }
          result[:model] = model_name
          break
        end
      end
    end

    # Поиск года
    year_matches = @query.scan(/\b(19|20)\d{2}\b/)
    if year_matches.any?
      result[:year] = year_matches.last.join.to_i
    end

    # Поиск диаметра
    diameter_matches = @query.scan(/\b(?:r)?(\d{2})\b/i)
    if diameter_matches.any?
      diameter = diameter_matches.last.first.to_i
      result[:diameter] = diameter if diameter >= 13 && diameter <= 24
    end

    # Поиск ширины шин
    width_matches = @query.scan(/\b(\d{3})\/?\d*\b/)
    if width_matches.any?
      width = width_matches.last.first.to_i
      result[:width] = width if width >= 145 && width <= 335
    end

    result
  end

  def needs_llm_parsing?
    # Используем LLM если:
    complex_patterns = [
      @parsed_data[:brand].nil?,                    # Не нашли бренд
      @query.split.length > 6,                     # Сложный запрос
      @query.match?(/какие|посоветуйте|подойдет|нужны|резина|шины/i), # Вопросительная форма
      @query.match?(/поменял|купил|продал|заменил/i) # Контекстные слова
    ]

    complex_patterns.any?
  end

  def parse_with_llm
    # Заглушка для LLM парсинга
    # В реальной реализации здесь будет интеграция с OpenAI
    Rails.logger.info "LLM parsing would be used for query: #{@query}"
    
    # Возвращаем пустой результат для простой реализации
    {}
  rescue => e
    Rails.logger.error "LLM parsing failed: #{e.message}"
    {}
  end

  def search_configurations
    # Используем модель для поиска с приоритетом распознанных параметров
    search_params = @parsed_data.dup
    
    # Если не нашли конкретные параметры, используем общий поиск
    search_params[:query] = @query if search_params.empty? || search_params.values.compact.empty?
    
    Rails.logger.info "Search params: #{search_params.inspect}"
    
    CarTireConfiguration.search_with_filters(search_params)
                        .limit(@options[:limit] || 20)
                        .offset(@options[:offset] || 0)
  end

  def format_results(configurations)
    configurations.map do |config|
      {
        id: config.id,
        brand: config.brand.name,
        model: config.model.name,
        full_name: config.full_name,
        year_range: config.year_range,
        tire_sizes: config.formatted_tire_sizes,
        stock_sizes: config.stock_tire_sizes.map { |s| format_tire_size(s) },
        optional_sizes: config.optional_tire_sizes.map { |s| format_tire_size(s) },
        all_diameters: config.all_diameters,
        match_score: calculate_match_score(config),
        data_version: config.data_version
      }
    end
  end

  def format_tire_size(size)
    "#{size['width']}/#{size['height']}R#{size['diameter']}"
  end

  def calculate_match_score(config)
    score = 0
    query_lower = @query.downcase

    # Точное совпадение бренда
    score += 10 if query_lower.include?(config.brand.name.downcase)

    # Точное совпадение модели
    score += 8 if query_lower.include?(config.model.name.downcase)

    # Совпадение по поисковым токенам
    if config.search_tokens.present?
      score += 5 if config.search_tokens.downcase.include?(query_lower)
    end

    # Совпадение по году
    if @parsed_data[:year] && config.year_from <= @parsed_data[:year] && config.year_to >= @parsed_data[:year]
      score += 6
    end

    # Совпадение по диаметру
    if @parsed_data[:diameter] && config.all_diameters.include?(@parsed_data[:diameter])
      score += 4
    end

    score
  end

  def generate_suggestions
    return [] if @parsed_data[:brand].present?

    # Генерируем предложения на основе популярных поисков
    suggestions = []

    # Если нашли только модель без бренда
    if @parsed_data[:model].present?
      BRAND_ALIASES.keys.flatten.sample(3).each do |brand_alias|
        suggestions << "#{brand_alias} #{@parsed_data[:model]}"
      end
    end

    # Если вообще ничего не нашли
    if @parsed_data.empty?
      suggestions = [
        'BMW 3 Series',
        'Volkswagen Tiguan',
        'Mercedes C-Class',
        'Toyota Camry',
        'Honda Civic'
      ]
    end

    suggestions.take(5)
  end

  # Класс для статистики поиска
  class SearchStats
    def self.record_search(query, results_count, parsed_data = {})
      # Здесь можно записывать статистику поиска в Redis или БД
      Rails.logger.info "Search: '#{query}' -> #{results_count} results, parsed: #{parsed_data}"
    end

    def self.popular_queries(limit = 10)
      # Заглушка для популярных запросов
      [
        'BMW 3 Series',
        'Volkswagen Tiguan',
        'Mercedes C-Class',
        'Toyota Camry',
        'Honda Civic'
      ].take(limit)
    end
  end
end