# frozen_string_literal: true

module TireSearch
  # QueryParser - парсинг текстового запроса на компоненты
  # Извлекает: бренд авто, модель, размеры шин, сезонность, бренды шин
  class QueryParser
    # Константы валидации размеров шин
    VALID_WIDTH_RANGE = (125..355).freeze
    VALID_HEIGHT_RANGE = (25..85).freeze
    VALID_DIAMETER_RANGE = (12..24).freeze

    # Ссылки на константы из TireSearchService для обратной совместимости
    BRAND_ALIASES = TireSearchService::BRAND_ALIASES
    MODEL_ALIASES = TireSearchService::MODEL_ALIASES
    TIRE_BRANDS = TireSearchService::TIRE_BRANDS
    TIRE_BRAND_ALIASES = TireSearchService::TIRE_BRAND_ALIASES
    SEASONALITY_ALIASES = TireSearchService::SEASONALITY_ALIASES

    attr_reader :query

    def initialize(query)
      @query = query.to_s.strip
      @query_lower = @query.downcase
    end

    # Главный метод парсинга
    def parse
      result = {}

      # Порядок важен - сначала полный размер, потом частичный
      result.merge!(parse_full_tire_size)
      result.merge!(parse_partial_tire_size) if result[:tire_size].blank?
      result.merge!(parse_car_brand)
      result.merge!(parse_car_model(result[:brand]))
      result.merge!(parse_year)
      result.merge!(parse_tire_brands)
      result.merge!(parse_seasonality)

      result
    end

    private

    # === Парсинг размера шин ===

    def parse_full_tire_size
      # Формат 1: 225/50R17 (стандартный)
      if (match = @query.match(/\b(\d{3})\/(\d{2})r(\d{2})\b/i))
        return build_tire_size(match[1], match[2], match[3])
      end

      # Формат 2: 225/50/17 (со слэшами)
      if (match = @query.match(/\b(\d{3})\/(\d{2})\/(\d{2})\b/))
        return build_tire_size(match[1], match[2], match[3])
      end

      # Формат 3: 175 70 13 (через пробелы)
      if (match = @query.match(/\b(\d{3})\s+(\d{2})\s+(\d{2})\b/))
        return build_tire_size(match[1], match[2], match[3])
      end

      # Формат 4: 175-70-13 (через дефисы)
      if (match = @query.match(/\b(\d{3})-(\d{2})-(\d{2})\b/))
        return build_tire_size(match[1], match[2], match[3])
      end

      # Формат 5: 175/70 р13 (с пробелом перед R)
      if (match = @query.match(/\b(\d{3})\/(\d{2})\s+р?(\d{2})\b/i))
        return build_tire_size(match[1], match[2], match[3])
      end

      {}
    end

    def build_tire_size(width_str, height_str, diameter_str)
      width = width_str.to_i
      height = height_str.to_i
      diameter = diameter_str.to_i

      return {} unless valid_tire_size?(width, height, diameter)

      {
        tire_size: {
          width: width,
          height: height,
          diameter: diameter,
          full_size: "#{width}/#{height}R#{diameter}"
        },
        width: width,
        height: height,
        diameter: diameter
      }
    end

    def valid_tire_size?(width, height, diameter)
      VALID_WIDTH_RANGE.include?(width) &&
        VALID_HEIGHT_RANGE.include?(height) &&
        VALID_DIAMETER_RANGE.include?(diameter)
    end

    def parse_partial_tire_size
      params = extract_tire_parameters
      result = {}

      result[:width] = params[:width] if params[:width]
      result[:height] = params[:height] if params[:height]
      result[:diameter] = params[:diameter] if params[:diameter]

      result
    end

    def extract_tire_parameters
      params = { width: nil, height: nil, diameter: nil }

      # 1. Ищем диаметр (с контекстом)
      diameter_matches = @query.scan(/(?:на\s+|r|\/|диаметр\s*)(\d{2})\b/i)
      if diameter_matches.any?
        diameter = diameter_matches.last.first.to_i
        params[:diameter] = diameter if VALID_DIAMETER_RANGE.include?(diameter)
      end

      # 2. Собираем все числа
      all_numbers = @query.scan(/\b(\d{2,3})\b/).flatten.map(&:to_i)

      # Исключаем диаметр и годы
      excluded = []
      excluded << params[:diameter] if params[:diameter]
      excluded += @query.scan(/\b((19|20)\d{2})\b/).flatten.map(&:to_i)

      available = all_numbers - excluded

      # 3. Ширина (3 цифры, 125-355)
      width_candidates = available.select { |n| VALID_WIDTH_RANGE.include?(n) }
      if width_candidates.any?
        params[:width] = width_candidates.first
        available.delete(params[:width])
      end

      # 4. Высота (2 цифры, 25-85)
      height_candidates = available.select { |n| VALID_HEIGHT_RANGE.include?(n) }
      if height_candidates.any?
        params[:height] = height_candidates.first
        available.delete(params[:height])
      end

      # 5. Диаметр из оставшихся (если не найден ранее)
      if params[:diameter].nil?
        diameter_candidates = available.select { |n| VALID_DIAMETER_RANGE.include?(n) }
        params[:diameter] = diameter_candidates.first if diameter_candidates.any?
      end

      params
    end

    # === Парсинг бренда автомобиля ===

    def parse_car_brand
      BRAND_ALIASES.each do |aliases, brand_name|
        if aliases.any? { |alias_name| @query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
          return { brand: brand_name }
        end
      end

      # Динамический поиск в БД
      dynamic_brand = find_brand_in_database
      return { brand: dynamic_brand } if dynamic_brand.present?

      {}
    end

    def find_brand_in_database
      words = @query_lower.split(/[\s\+]+/).reject do |w|
        %w[шины на для под авто автомобиль машину].include?(w) || w.length < 2
      end

      words.each do |word|
        transliterated = transliterate_to_latin(word)

        brand = CarBrand.where(is_active: true)
                       .where('LOWER(name) = ? OR LOWER(name) LIKE ?', transliterated, "#{transliterated}%")
                       .first

        return brand.name if brand
      end

      nil
    end

    def transliterate_to_latin(word)
      # Специальные случаи для брендов
      brand_map = {
        'теслу' => 'tesla', 'тесла' => 'tesla',
        'бмв' => 'bmw', 'мерседес' => 'mercedes', 'мерс' => 'mercedes',
        'вольво' => 'volvo', 'ауди' => 'audi',
        'тойота' => 'toyota', 'хонда' => 'honda',
        'ниссан' => 'nissan', 'мазда' => 'mazda',
        'хёндай' => 'hyundai', 'хундай' => 'hyundai',
        'киа' => 'kia', 'шкода' => 'skoda',
        'фольксваген' => 'volkswagen'
      }

      normalized = word.gsub(/[^\w]/, '').downcase
      brand_map[normalized] || normalized
    end

    # === Парсинг модели автомобиля ===

    def parse_car_model(brand)
      return {} unless brand && MODEL_ALIASES[brand]

      MODEL_ALIASES[brand].each do |aliases, model_name|
        if aliases.any? { |alias_name| @query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
          return { model: model_name }
        end
      end

      # Поиск с расширениями двигателей
      model = find_model_with_engine_extensions(brand)
      return { model: model } if model

      {}
    end

    def find_model_with_engine_extensions(brand)
      return nil unless MODEL_ALIASES[brand]

      engine_extensions = %w[i d cdi tdi tfsi tsi dci hdi bluemotion xdrive quattro]

      MODEL_ALIASES[brand].each do |aliases, model_name|
        aliases.each do |alias_name|
          engine_extensions.each do |ext|
            patterns = ["#{alias_name}#{ext}", "#{alias_name} #{ext}", "#{alias_name}-#{ext}"]
            if patterns.any? { |p| @query_lower.match?(/\b#{Regexp.escape(p)}\b/) }
              return model_name
            end
          end
        end
      end

      nil
    end

    # === Парсинг года ===

    def parse_year
      year_matches = @query.scan(/\b((19|20)\d{2})\b/)
      return {} unless year_matches.any?

      { year: year_matches.last.first.to_i }
    end

    # === Парсинг брендов шин ===

    def parse_tire_brands
      tire_brands = []

      TIRE_BRAND_ALIASES.each do |aliases, brand_name|
        if aliases.any? { |alias_name| @query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
          tire_brands << brand_name
        end
      end

      tire_brands.any? ? { tire_brands: tire_brands } : {}
    end

    # === Парсинг сезонности ===

    def parse_seasonality
      SEASONALITY_ALIASES.each do |aliases, season|
        if aliases.any? { |alias_name| @query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
          return { seasonality: season }
        end
      end

      {}
    end
  end
end
