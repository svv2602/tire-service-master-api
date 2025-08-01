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

  # Константы производителей шин (топ-100)
  TIRE_BRANDS = [
    'Michelin', 'Bridgestone', 'Continental', 'Pirelli', 'Goodyear', 'Dunlop', 'Yokohama',
    'Hankook', 'Kumho', 'Toyo', 'Falken', 'Nokian', 'Cooper', 'BFGoodrich', 'Uniroyal',
    'General', 'Maxxis', 'Nitto', 'Nexen', 'GT Radial', 'Achilles', 'Accelera', 'Federal',
    'Nankang', 'Linglong', 'Triangle', 'Roadstone', 'Matador', 'Barum', 'Sava', 'Vredestein',
    'Semperit', 'Gislaved', 'Cordiant', 'Kama', 'Viatti', 'Амтел', 'Белшина', 'Росава'
  ].freeze

  # Алиасы производителей шин
  TIRE_BRAND_ALIASES = {
    ['michelin', 'мишлен', 'мишелин'] => 'Michelin',
    ['bridgestone', 'бриджстоун', 'бриджстон'] => 'Bridgestone',
    ['continental', 'континенталь', 'конти'] => 'Continental',
    ['pirelli', 'пирелли'] => 'Pirelli',
    ['goodyear', 'гудьир', 'гудиер'] => 'Goodyear',
    ['dunlop', 'данлоп'] => 'Dunlop',
    ['yokohama', 'йокохама'] => 'Yokohama',
    ['hankook', 'ханкок'] => 'Hankook',
    ['kumho', 'кумхо'] => 'Kumho',
    ['nokian', 'нокиан'] => 'Nokian',
    ['cooper', 'купер'] => 'Cooper',
    ['toyo', 'тойо'] => 'Toyo',
    ['falken', 'фалькен'] => 'Falken'
  }.freeze

  # Константы сезонности
  SEASONALITY_ALIASES = {
    ['зимние', 'зима', 'winter', 'зимняя резина', 'зимняя', 'snow'] => 'winter',
    ['летние', 'лето', 'summer', 'летняя резина', 'летняя'] => 'summer',
    ['всесезонные', 'всесезон', 'all season', 'всесезонная', 'круглогодичные'] => 'all_season'
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
    return build_empty_response if @query.blank?

    # Шаг 1: Простой парсинг
    @parsed_data = parse_simple_query

    # Шаг 2: Если простой парсинг неполный и включен LLM - используем LLM
    if needs_llm_parsing? && @use_llm
      llm_result = parse_with_llm
      @parsed_data = @parsed_data.merge(llm_result) if llm_result.present?
    end

    # Шаг 3: Определяем сценарий поиска и обрабатываем
    response = process_search_scenario

    response
  end

  private

  def build_empty_response
    {
      success: false,
      message: "Запрос не может быть пустым",
      tire_sizes: [],
      tire_brands: [],
      seasonality: nil,
      car_info: {},
      query: @query,
      parsed_data: {},
      suggestions: generate_suggestions
    }
  end

  def process_search_scenario
    car_identified = @parsed_data[:brand].present? && @parsed_data[:model].present?
    
    if car_identified
      # Сценарии 1-3: Автомобиль определен
      process_car_identified_scenario
    elsif @parsed_data[:tire_size].present? || @parsed_data[:diameter].present?
      # Есть размер шин, но авто не определено
      process_tire_size_only_scenario
    else
      # Недостаточно данных
      process_insufficient_data_scenario
    end
  end

  def process_car_identified_scenario
    # Поиск размеров для определенного автомобиля
    car_configurations = find_car_configurations
    
    if car_configurations.empty?
      return {
        success: false,
        message: "Автомобиль #{@parsed_data[:brand]} #{@parsed_data[:model]} не найден в базе данных",
        tire_sizes: [],
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: extract_car_info,
        query: @query,
        parsed_data: @parsed_data,
        suggestions: generate_car_suggestions
      }
    end

    # Извлекаем размеры шин для автомобиля
    tire_sizes = extract_tire_sizes_from_configurations(car_configurations)
    
    # Фильтруем по диаметру если указан
    if @parsed_data[:diameter].present?
      tire_sizes = tire_sizes.select { |size| size[:diameter] == @parsed_data[:diameter] }
    end

    # Проверяем указанный размер шин
    validation_result = validate_tire_size_for_car(tire_sizes)

    {
      success: true,
      message: validation_result[:message],
      tire_sizes: validation_result[:tire_sizes],
      tire_brands: @parsed_data[:tire_brands] || [],
      seasonality: @parsed_data[:seasonality],
      car_info: extract_car_info,
      query: @query,
      parsed_data: @parsed_data,
      warnings: validation_result[:warnings] || []
    }
  end

  def process_tire_size_only_scenario
    # Указан размер шин, но автомобиль не определен
    tire_sizes = []
    
    if @parsed_data[:tire_size].present?
      tire_sizes << @parsed_data[:tire_size]
    elsif @parsed_data[:width].present? && @parsed_data[:height].present? && @parsed_data[:diameter].present?
      tire_sizes << {
        width: @parsed_data[:width],
        height: @parsed_data[:height],
        diameter: @parsed_data[:diameter]
      }
    end

    {
      success: true,
      message: "Найден размер шин, но автомобиль не определен. Рекомендуем указать марку и модель для более точного подбора.",
      tire_sizes: tire_sizes,
      tire_brands: @parsed_data[:tire_brands] || [],
      seasonality: @parsed_data[:seasonality],
      car_info: {},
      query: @query,
      parsed_data: @parsed_data,
      suggestions: generate_car_brand_suggestions
    }
  end

  def process_insufficient_data_scenario
    {
      success: false,
      message: "Недостаточно данных для поиска. Пожалуйста, укажите марку и модель автомобиля или размер шин.",
      tire_sizes: [],
      tire_brands: @parsed_data[:tire_brands] || [],
      seasonality: @parsed_data[:seasonality],
      car_info: {},
      query: @query,
      parsed_data: @parsed_data,
      suggestions: generate_suggestions
    }
  end

  def parse_simple_query
    result = {}
    query_lower = @query.downcase

    # Поиск полного размера шин (приоритет)
    # Формат 1: 225/50R17 (стандартный)
    tire_size_matches = @query.scan(/\b(\d{3})\/(\d{2})r(\d{2})\b/i)
    
    # Формат 2: 225/50/17 (со слэшами)
    if tire_size_matches.empty?
      tire_size_matches = @query.scan(/\b(\d{3})\/(\d{2})\/(\d{2})\b/)
    end
    
    if tire_size_matches.any?
      width, height, diameter = tire_size_matches.last.map(&:to_i)
      if width >= 145 && width <= 335 && height >= 25 && height <= 85 && diameter >= 13 && diameter <= 24
        result[:tire_size] = {
          width: width,
          height: height,
          diameter: diameter,
          full_size: "#{width}/#{height}R#{diameter}"
        }
      end
    end

    # Поиск бренда автомобиля (только целые слова)
    BRAND_ALIASES.each do |aliases, brand_name|
      if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
        result[:brand] = brand_name
        break
      end
    end

    # Поиск модели (если найден бренд)
    if result[:brand] && MODEL_ALIASES[result[:brand]]
      MODEL_ALIASES[result[:brand]].each do |aliases, model_name|
        if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
          result[:model] = model_name
          break
        end
      end
    end

    # Поиск модели без бренда (для уникальных моделей)
    if result[:model].blank?
      MODEL_ALIASES.each do |brand, models|
        models.each do |aliases, model_name|
          if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
            # Проверяем уникальность модели
            if is_unique_model?(model_name)
              result[:model] = model_name
              result[:brand] = brand
              break
            end
          end
        end
        break if result[:model].present?
      end
    end

    # Поиск года
    year_matches = @query.scan(/\b((19|20)\d{2})\b/)
    if year_matches.any?
      result[:year] = year_matches.last.first.to_i
    end

    # Поиск отдельных параметров размера (если не найден полный размер)
    unless result[:tire_size]
      # Найдем все числа в запросе и определим их типы
      tire_params = extract_tire_parameters(@query)
      
      if tire_params[:width] && tire_params[:height] && tire_params[:diameter]
        result[:tire_size] = {
          width: tire_params[:width],
          height: tire_params[:height],
          diameter: tire_params[:diameter],
          full_size: "#{tire_params[:width]}/#{tire_params[:height]}R#{tire_params[:diameter]}"
        }
      else
        # Сохраняем найденные отдельные параметры
        result[:width] = tire_params[:width] if tire_params[:width]
        result[:height] = tire_params[:height] if tire_params[:height]
        result[:diameter] = tire_params[:diameter] if tire_params[:diameter]
      end
    end

    # Поиск производителей шин (только целые слова)
    tire_brands = []
    TIRE_BRAND_ALIASES.each do |aliases, brand_name|
      if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
        tire_brands << brand_name
      end
    end
    result[:tire_brands] = tire_brands if tire_brands.any?

    # Поиск сезонности (только целые слова)
    SEASONALITY_ALIASES.each do |aliases, season|
      if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
        result[:seasonality] = season
        break
      end
    end

    result
  end

  def find_car_configurations
    scope = CarTireConfiguration.active.not_deprecated
    scope = scope.for_brand(@parsed_data[:brand]) if @parsed_data[:brand].present?
    scope = scope.for_model(@parsed_data[:model]) if @parsed_data[:model].present?
    scope = scope.for_year(@parsed_data[:year]) if @parsed_data[:year].present?
    scope.includes(:brand, :model)
  end

  def extract_tire_sizes_from_configurations(configurations)
    tire_sizes = []
    configurations.each do |config|
      config.tire_sizes.each do |size|
        tire_sizes << {
          width: size['width'],
          height: size['height'],
          diameter: size['diameter'],
          type: size['type']
        }
      end
    end
    tire_sizes.uniq
  end

  def validate_tire_size_for_car(available_sizes)
    if @parsed_data[:tire_size].present?
      # Проверяем указанный полный размер
      requested_size = @parsed_data[:tire_size]
      matching_size = available_sizes.find do |size|
        size[:width] == requested_size[:width] &&
        size[:height] == requested_size[:height] &&
        size[:diameter] == requested_size[:diameter]
      end

      if matching_size
        {
          message: "Размер #{requested_size[:full_size]} подходит для данного автомобиля",
          tire_sizes: [requested_size]
        }
      else
        {
          message: "Размер #{requested_size[:full_size]} не найден для данного автомобиля, но возвращаем его по запросу",
          tire_sizes: [requested_size],
          warnings: ["Указанный размер может не подходить для данного автомобиля"]
        }
      end
    else
      # Возвращаем все доступные размеры
      {
        message: "Найдены размеры шин для #{@parsed_data[:brand]} #{@parsed_data[:model]}",
        tire_sizes: available_sizes
      }
    end
  end

  def extract_car_info
    info = {}
    info[:brand] = @parsed_data[:brand] if @parsed_data[:brand].present?
    info[:model] = @parsed_data[:model] if @parsed_data[:model].present?
    info[:year] = @parsed_data[:year] if @parsed_data[:year].present?
    info
  end

  def generate_car_suggestions
    # Предложения похожих автомобилей
    suggestions = []
    if @parsed_data[:brand].present?
      # Предлагаем другие модели того же бренда
      if MODEL_ALIASES[@parsed_data[:brand]]
        MODEL_ALIASES[@parsed_data[:brand]].each do |aliases, model_name|
          suggestions << "#{@parsed_data[:brand]} #{model_name}"
        end
      end
    end
    suggestions.take(5)
  end

  def generate_car_brand_suggestions
    # Предложения брендов автомобилей
    BRAND_ALIASES.values.sample(5)
  end

  def extract_tire_parameters(query)
    # Извлекаем все числа из запроса с контекстом
    params = { width: nil, height: nil, diameter: nil }
    
    # 1. Ищем диаметр (с контекстными подсказками)
    diameter_matches = query.scan(/(?:на\s+|r)(\d{2})\b/i)
    if diameter_matches.any?
      diameter = diameter_matches.last.first.to_i
      params[:diameter] = diameter if diameter >= 13 && diameter <= 24
    end
    
    # 2. Ищем все двузначные и трехзначные числа
    all_numbers = query.scan(/\b(\d{2,3})\b/).flatten.map(&:to_i)
    
    # Исключаем уже найденный диаметр и года
    excluded_numbers = []
    excluded_numbers << params[:diameter] if params[:diameter]
    excluded_numbers += query.scan(/\b((19|20)\d{2})\b/).flatten.map(&:to_i)
    
    available_numbers = all_numbers - excluded_numbers
    
    # 3. Определяем ширину (трехзначное число 145-335)
    width_candidates = available_numbers.select { |n| n >= 145 && n <= 335 }
    if width_candidates.any?
      params[:width] = width_candidates.first
      available_numbers.delete(params[:width])
    end
    
    # 4. Определяем высоту (двузначное число 25-85)
    height_candidates = available_numbers.select { |n| n >= 25 && n <= 85 }
    if height_candidates.any?
      params[:height] = height_candidates.first
      available_numbers.delete(params[:height])
    end
    
    # 5. Если диаметр не найден по контексту, ищем среди оставшихся чисел
    if params[:diameter].nil?
      diameter_candidates = available_numbers.select { |n| n >= 13 && n <= 24 }
      if diameter_candidates.any?
        params[:diameter] = diameter_candidates.first
      end
    end
    
    params
  end

  def is_unique_model?(model_name)
    # Проверяем, встречается ли модель только у одного бренда
    brands_with_model = MODEL_ALIASES.count do |brand, models|
      models.any? { |aliases, name| name == model_name }
    end
    brands_with_model == 1
  end

  def needs_llm_parsing?
    # Не используем LLM если простой парсинг дал хорошие результаты
    if @parsed_data[:brand].present? && @parsed_data[:model].present?
      return false
    end

    # Используем LLM если:
    complex_patterns = [
      @parsed_data[:brand].nil? && @query.split.length > 3, # Не нашли бренд в сложном запросе
      @query.match?(/какие|посоветуйте|подойдет|нужны|помогите|скажите|подскажите/i), # Вопросительная форма
      @query.match?(/поменял|купил|заменил|установил|ищу|хочу/i), # Контекстные слова
      @query.split.length > 8,                     # Очень сложный запрос
      @query.match?(/не знаю|не уверен|не помню/i) # Неопределенность
    ]

    complex_patterns.any?
  end

  def parse_with_llm
    return {} unless OpenaiService.available?

    Rails.logger.info "🤖 Используем LLM для парсинга запроса: #{@query}"
    
    begin
      openai_service = OpenaiService.new
      result = openai_service.parse_tire_search_query(@query)
      
      if result.present?
        Rails.logger.info "✅ LLM успешно распарсил запрос: #{result.inspect}"
      else
        Rails.logger.warn "⚠️ LLM не смог распарсить запрос"
      end
      
      result
    rescue => e
      Rails.logger.error "❌ Ошибка LLM парсинга: #{e.message}"
      {}
    end
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