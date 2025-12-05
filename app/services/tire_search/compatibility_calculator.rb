# frozen_string_literal: true

module TireSearch
  # CompatibilityCalculator - расчёт совместимости шин с автомобилем
  # Отвечает за: поиск совместимых размеров, расчёт score
  class CompatibilityCalculator
    # Типы размеров шин
    SIZE_TYPES = {
      stock: 'stock',           # Заводской размер
      optional: 'optional',     # Опциональный (от производителя)
      aftermarket: 'aftermarket' # Aftermarket (не от производителя)
    }.freeze

    # Веса для расчёта compatibility score
    SCORE_WEIGHTS = {
      exact_match: 100,
      stock_size: 50,
      optional_size: 30,
      year_match: 20,
      modification_match: 10
    }.freeze

    # Константы алиасов для брендов автомобилей
    BRAND_ALIASES = {
      ['bmw', 'бмв', 'бэмв'] => 'BMW',
      ['volkswagen', 'vw', 'фольксваген', 'фольц'] => 'Volkswagen',
      ['mercedes', 'мерседес', 'мерс', 'mercedes-benz'] => 'Mercedes',
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
      ['volvo', 'вольво'] => 'Volvo',
      ['mitsubishi', 'митсубиси'] => 'Mitsubishi',
      ['tesla', 'тесла'] => 'Tesla',
      ['chevrolet', 'шевроле'] => 'Chevrolet',
      ['suzuki', 'сузуки'] => 'Suzuki',
      ['geely', 'джили'] => 'Geely'
    }.freeze

    attr_reader :vehicle

    def initialize(vehicle = {})
      @vehicle = normalize_vehicle(vehicle)
    end

    # Главный метод - найти совместимые размеры для автомобиля
    def find_compatible_sizes
      return [] unless valid_vehicle?

      configurations = find_car_configurations
      return [] if configurations.empty?

      extract_tire_sizes(configurations)
    end

    # Рассчитать score совместимости для конкретной шины
    def calculate_compatibility_score(tire_size)
      return 0 unless valid_vehicle? && tire_size.present?

      score = 0
      compatible_sizes = find_compatible_sizes

      return 0 if compatible_sizes.empty?

      matching_size = find_matching_size(tire_size, compatible_sizes)
      return 0 unless matching_size

      score += SCORE_WEIGHTS[:exact_match] if exact_size_match?(tire_size, matching_size)
      score += SCORE_WEIGHTS[:stock_size] if matching_size[:type] == SIZE_TYPES[:stock]
      score += SCORE_WEIGHTS[:optional_size] if matching_size[:type] == SIZE_TYPES[:optional]
      score += SCORE_WEIGHTS[:year_match] if year_matches?
      score += SCORE_WEIGHTS[:modification_match] if modification_matches?

      score
    end

    # Проверить совместимость конкретного размера
    def compatible?(tire_size)
      calculate_compatibility_score(tire_size) > 0
    end

    # Получить OEM размеры (заводские)
    def oem_sizes
      find_compatible_sizes.select { |s| s[:type] == SIZE_TYPES[:stock] }
    end

    # Получить aftermarket размеры
    def aftermarket_sizes
      find_compatible_sizes.select { |s| s[:type] == SIZE_TYPES[:aftermarket] }
    end

    # Нормализовать бренд автомобиля
    def self.normalize_brand(brand_input)
      return nil if brand_input.blank?

      brand_lower = brand_input.to_s.downcase.strip

      BRAND_ALIASES.each do |aliases, brand_name|
        return brand_name if aliases.include?(brand_lower)
      end

      # Если не найдено в алиасах, возвращаем как есть с заглавной буквы
      brand_input.to_s.strip.titleize
    end

    private

    def normalize_vehicle(vehicle_data)
      return {} unless vehicle_data.is_a?(Hash)

      {
        brand: self.class.normalize_brand(vehicle_data[:brand]),
        model: vehicle_data[:model]&.to_s&.strip,
        year: vehicle_data[:year]&.to_i,
        modification: vehicle_data[:modification]&.to_s&.strip,
        diameter: vehicle_data[:diameter]&.to_i
      }.compact
    end

    def valid_vehicle?
      vehicle[:brand].present? && vehicle[:model].present?
    end

    def find_car_configurations
      scope = CarTireConfiguration.active.not_deprecated

      scope = scope.for_brand(vehicle[:brand]) if vehicle[:brand].present?
      scope = scope.for_model(vehicle[:model]) if vehicle[:model].present?
      scope = scope.for_year(vehicle[:year]) if vehicle[:year].present? && vehicle[:year] > 0

      scope.includes(:brand, :model)
    end

    def extract_tire_sizes(configurations)
      tire_sizes = []

      configurations.each do |config|
        config.tire_sizes.each do |size|
          next if vehicle[:diameter].present? && size['diameter'] != vehicle[:diameter]

          tire_sizes << {
            width: size['width'],
            height: size['height'],
            diameter: size['diameter'],
            type: size['type'] || SIZE_TYPES[:stock],
            full_size: "#{size['width']}/#{size['height']}R#{size['diameter']}",
            configuration_id: config.id,
            year_from: config.year_from,
            year_to: config.year_to
          }
        end
      end

      tire_sizes.uniq { |s| [s[:width], s[:height], s[:diameter]] }
    end

    def find_matching_size(tire_size, compatible_sizes)
      width = tire_size[:width] || tire_size['width']
      height = tire_size[:height] || tire_size['height']
      diameter = tire_size[:diameter] || tire_size['diameter']

      compatible_sizes.find do |size|
        size[:width] == width &&
          size[:height] == height &&
          size[:diameter] == diameter
      end
    end

    def exact_size_match?(tire_size, matching_size)
      width = tire_size[:width] || tire_size['width']
      height = tire_size[:height] || tire_size['height']
      diameter = tire_size[:diameter] || tire_size['diameter']

      matching_size[:width] == width &&
        matching_size[:height] == height &&
        matching_size[:diameter] == diameter
    end

    def year_matches?
      return false unless vehicle[:year].present? && vehicle[:year] > 0

      configurations = find_car_configurations
      configurations.any? do |config|
        config.year_from <= vehicle[:year] && config.year_to >= vehicle[:year]
      end
    end

    def modification_matches?
      return false unless vehicle[:modification].present?

      configurations = find_car_configurations
      configurations.any? do |config|
        config.modification&.downcase&.include?(vehicle[:modification].downcase)
      end
    end
  end
end
