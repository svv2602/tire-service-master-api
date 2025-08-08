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
      
      CarModel.where(brand_id: brand_ids)
              .where('name ILIKE ?', "%#{normalized_model}%")
              .includes(:brand)
              .map do |model|
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