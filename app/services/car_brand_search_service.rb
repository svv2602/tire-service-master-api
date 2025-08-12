# frozen_string_literal: true

# Сервис для умного поиска брендов автомобилей с обработкой неоднозначности
class CarBrandSearchService
  class << self
    # Основной метод поиска брендов
    # @param query [String] поисковый запрос
    # @return [Hash] результат поиска с вариантами
    def search(query)
      return { status: :empty, brands: [] } if query.blank?

      # Нормализуем запрос
      normalized_query = normalize_query(query)
      
      # Ищем точные совпадения
      exact_matches = find_exact_matches(normalized_query)
      return { status: :exact, brands: exact_matches } if exact_matches.size == 1

      # Ищем похожие бренды
      similar_brands = find_similar_brands(normalized_query)
      
      if similar_brands.empty?
        { status: :not_found, brands: [] }
      elsif similar_brands.size == 1
        { status: :exact, brands: similar_brands }
      else
        { status: :multiple, brands: similar_brands, query: query }
      end
    end

    # Поиск моделей в рамках найденных брендов
    # @param brand_ids [Array<Integer>] ID брендов
    # @param model_query [String] запрос модели
    # @return [Array<Hash>] найденные модели
    def search_models(brand_ids, model_query)
      return [] if brand_ids.empty?

      normalized_model = normalize_query(model_query)
      
      # Маппинг алиасов для популярных моделей
      model_aliases = {
        # BMW
        '320i' => '3 Series',
        '320d' => '3 Series',
        '325i' => '3 Series',
        '330i' => '3 Series',
        '335i' => '3 Series',
        '520i' => '5 Series',
        '525i' => '5 Series',
        '530i' => '5 Series',
        '535i' => '5 Series',
        '740i' => '7 Series',
        '750i' => '7 Series',
        
        # Mercedes GLE модификации (английские и русские варианты)
        # Базовые модели без модификаций
        'gle' => 'GLE-Class',
        'жле' => 'GLE-Class',
        'гле' => 'GLE-Class',
        # Модификации
        'gle 200d' => 'GLE-Class',
        'gle 220d' => 'GLE-Class',
        'gle 250d' => 'GLE-Class',
        'gle 300d' => 'GLE-Class',
        'gle 350d' => 'GLE-Class',
        'gle 400d' => 'GLE-Class',
        'gle 450d' => 'GLE-Class',
        'gle 400' => 'GLE-Class',
        'gle 450' => 'GLE-Class',
        'gle 500' => 'GLE-Class',
        'gle 580' => 'GLE-Class',
        'gle 63 amg' => 'GLE-Class AMG',
        'gle 63s amg' => 'GLE-Class AMG',
        'gle amg 63' => 'GLE-Class AMG',
        'gle amg 63s' => 'GLE-Class AMG',
        # Русские варианты
        'жле 200д' => 'GLE-Class',
        'жле 220д' => 'GLE-Class',
        'жле 250д' => 'GLE-Class',
        'жле 300д' => 'GLE-Class',
        'жле 350д' => 'GLE-Class',
        'жле 400д' => 'GLE-Class',
        'жле 450д' => 'GLE-Class',
        'жле 400' => 'GLE-Class',
        'жле 450' => 'GLE-Class',
        'жле 500' => 'GLE-Class',
        'жле 580' => 'GLE-Class',
        'гле 200д' => 'GLE-Class',
        'гле 220д' => 'GLE-Class',
        'гле 250д' => 'GLE-Class',
        'гле 300д' => 'GLE-Class',
        'гле 350д' => 'GLE-Class',
        'гле 400д' => 'GLE-Class',
        'гле 450д' => 'GLE-Class',
        'гле 400' => 'GLE-Class',
        'гле 450' => 'GLE-Class',
        'гле 500' => 'GLE-Class',
        'гле 580' => 'GLE-Class',
        
        # Mercedes GLE Coupe модификации
        'gle coupe 350d' => 'GLE-Class Coupe',
        'gle coupe 400d' => 'GLE-Class Coupe',
        'gle coupe 450d' => 'GLE-Class Coupe',
        'gle coupe 500' => 'GLE-Class Coupe',
        'gle coupe 63 amg' => 'GLE-Class Coupe AMG',
        'gle coupe 63s amg' => 'GLE-Class Coupe AMG'
      }
      
      # Проверяем алиасы - они имеют приоритет!
      if model_aliases[normalized_model]
        exact_model_name = model_aliases[normalized_model]
        # Ищем точное совпадение по алиасу
        exact_models = CarModel.where(brand_id: brand_ids)
                              .where('name = ?', exact_model_name)
                              .includes(:brand)
        
        if exact_models.any?
          # Если нашли точное совпадение по алиасу - возвращаем только его
          return exact_models.map do |model|
            {
              id: model.id,
              name: model.name,
              brand_name: model.brand.name,
              brand_id: model.brand_id,
              configs_count: CarTireConfiguration.where(model_id: model.id).count
            }
          end
        end
      end

      # Если алиаса нет или точное совпадение не найдено, ищем по частичному совпадению
      models = CarModel.where(brand_id: brand_ids)
                      .where('name ILIKE ?', "%#{normalized_model}%")
                      .includes(:brand)
      
      # Убираем дубликаты и форматируем результат
      models.uniq.map do |model|
        {
          id: model.id,
          name: model.name,
          brand_name: model.brand.name,
          brand_id: model.brand_id,
          configs_count: CarTireConfiguration.where(model_id: model.id).count
        }
      end
    end

    # Получение размеров шин для конкретной модели и года
    # @param model_id [Integer] ID модели
    # @param year [Integer] год автомобиля
    # @return [Array<Hash>] размеры шин
    def get_tire_sizes(model_id, year = nil)
      configs = CarTireConfiguration.where(model_id: model_id)
      
      if year
        configs = configs.where('year_from <= ? AND (year_to IS NULL OR year_to >= ?)', year, year)
      end

      all_sizes = []
      configs.each do |config|
        next unless config.tire_sizes.is_a?(Array)
        
        config.tire_sizes.each do |size|
          all_sizes << {
            width: size['width'],
            height: size['height'],
            diameter: size['diameter'],
            type: size['type'] || 'stock',
            year_from: config.year_from,
            year_to: config.year_to
          }
        end
      end

      # Убираем дубликаты и сортируем
      unique_sizes = all_sizes.uniq { |s| [s[:width], s[:height], s[:diameter]] }
      unique_sizes.sort_by { |s| [s[:diameter], s[:width], s[:height]] }
    end

    private

    # Нормализация поискового запроса
    def normalize_query(query)
      query.to_s
           .downcase
           .strip
           .gsub(/[^\p{L}\p{N}\s-]/, '') # Убираем спецсимволы кроме дефисов
           .gsub(/\s+/, ' ') # Нормализуем пробелы
    end

    # Поиск точных совпадений
    def find_exact_matches(query)
      CarBrand.where('LOWER(name) = ?', query)
              .joins("LEFT JOIN car_tire_configurations ON car_brands.id = car_tire_configurations.brand_id")
              .group('car_brands.id, car_brands.name')
              .select('car_brands.*, COUNT(car_tire_configurations.id) as configs_count')
              .having('COUNT(car_tire_configurations.id) > 0') # Только бренды с данными
              .map { |b| format_brand(b) }
    end

    # Поиск похожих брендов
    def find_similar_brands(query)
      # Создаем список поисковых паттернов
      search_patterns = generate_search_patterns(query)
      
      brands = CarBrand.joins("LEFT JOIN car_tire_configurations ON car_brands.id = car_tire_configurations.brand_id")
                       .where(build_similarity_condition(search_patterns), *search_patterns)
                       .group('car_brands.id, car_brands.name')
                       .select('car_brands.*, COUNT(car_tire_configurations.id) as configs_count')
                       .having('COUNT(car_tire_configurations.id) > 0') # Только бренды с данными
                       .order('COUNT(car_tire_configurations.id) DESC') # Сортируем по количеству данных
                       .map { |b| format_brand(b) }

      # Убираем дубликаты и группируем похожие
      group_similar_brands(brands)
    end

    # Генерация паттернов для поиска
    def generate_search_patterns(query)
      patterns = []
      
      # Прямой поиск
      patterns << "%#{query}%"
      
      # Поиск без дефисов и пробелов
      clean_query = query.gsub(/[\s-]/, '')
      patterns << "%#{clean_query}%" if clean_query != query
      
      # Поиск по ключевым словам
      case query
      when /мерсед|mercedes|merc|benz/i
        patterns += ['%mercedes%', '%benz%', '%mb%']
      when /ваз|vaz|лада|lada/i
        patterns += ['%ваз%', '%vaz%', '%лада%', '%lada%']
      when /бмв|bmw/i
        patterns += ['%bmw%', '%бмв%']
      when /тойота|toyota/i
        patterns += ['%toyota%', '%тойота%']
      when /фольксваген|volkswagen|vw|фв/i
        patterns += ['%volkswagen%', '%vw%']
      when /ауди|audi/i
        patterns += ['%audi%', '%ауди%']
      when /ниссан|nissan/i
        patterns += ['%nissan%', '%ниссан%']
      end
      
      patterns.uniq
    end

    # Построение SQL условия для поиска
    def build_similarity_condition(patterns)
      conditions = patterns.map { 'LOWER(car_brands.name) ILIKE ?' }
      conditions.join(' OR ')
    end

    # Группировка похожих брендов
    def group_similar_brands(brands)
      # Для Mercedes группируем Mercedes, Mercedes-Benz, Mercedes-Maybach
      grouped = {}
      
      brands.each do |brand|
        key = determine_brand_group(brand[:name])
        grouped[key] ||= []
        grouped[key] << brand
      end

      # Возвращаем все бренды, но отсортированные по группам
      result = []
      grouped.each do |group, group_brands|
        # Сортируем внутри группы по количеству конфигураций
        sorted_brands = group_brands.sort_by { |b| -b[:configs_count] }
        result.concat(sorted_brands)
      end

      result
    end

    # Определение группы бренда
    def determine_brand_group(name)
      name_lower = name.downcase
      
      case name_lower
      when /mercedes|merc|benz/
        'mercedes'
      when /bmw|бмв/
        'bmw'
      when /toyota|тойота/
        'toyota'
      when /volkswagen|vw/
        'volkswagen'
      when /audi|ауди/
        'audi'
      when /ваз|vaz|лада|lada/
        'vaz'
      else
        name_lower
      end
    end

    # Форматирование данных бренда
    def format_brand(brand)
      {
        id: brand.id,
        name: brand.name,
        configs_count: brand.try(:configs_count) || 0,
        models_count: CarModel.where(brand_id: brand.id).count
      }
    end
  end
end