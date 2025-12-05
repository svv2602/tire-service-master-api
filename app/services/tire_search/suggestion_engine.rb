# frozen_string_literal: true

module TireSearch
  # SuggestionEngine - поисковые подсказки и автокомплит
  # Отвечает за: autocomplete, related searches, popular queries, spell check
  class SuggestionEngine
    # Лимиты
    MAX_SUGGESTIONS = 10
    MAX_RELATED = 5
    MAX_POPULAR = 10
    MIN_QUERY_LENGTH = 2

    # Популярные запросы (статические для быстрого доступа)
    POPULAR_QUERIES = [
      'BMW 3 Series',
      'Volkswagen Tiguan',
      'Mercedes C-Class',
      'Toyota Camry',
      'Honda Civic',
      'Renault Duster',
      'Hyundai Tucson',
      'Kia Sportage',
      'Audi A4',
      'Ford Focus'
    ].freeze

    # Бренды шин для автокомплита
    TIRE_BRANDS = %w[
      Michelin Bridgestone Continental Pirelli Goodyear
      Dunlop Yokohama Hankook Kumho Toyo
      Nokian Cooper Falken Nexen Maxxis
    ].freeze

    attr_reader :query

    def initialize(query = nil)
      @query = query&.to_s&.strip&.downcase
    end

    # Главный метод автокомплита
    def autocomplete
      return [] if query.blank? || query.length < MIN_QUERY_LENGTH

      suggestions = []
      suggestions.concat(brand_suggestions)
      suggestions.concat(model_suggestions)
      suggestions.concat(tire_brand_suggestions)
      suggestions.concat(size_suggestions)

      suggestions.uniq.first(MAX_SUGGESTIONS)
    end

    # Связанные поиски
    def related_searches
      return [] if query.blank?

      related = []

      # Если ищут бренд - предлагаем модели
      if detected_brand.present?
        related.concat(models_for_brand(detected_brand))
      end

      # Если ищут размер - предлагаем похожие размеры
      if detected_size.present?
        related.concat(similar_sizes(detected_size))
      end

      # Если ищут сезон - предлагаем другие сезоны
      if detected_season.present?
        related.concat(other_seasons(detected_season))
      end

      related.uniq.first(MAX_RELATED)
    end

    # Популярные запросы
    def popular_searches(limit = MAX_POPULAR)
      POPULAR_QUERIES.first(limit)
    end

    # Исправление опечаток (базовая реализация)
    def spell_check
      return nil if query.blank?

      corrected = correct_brand_spelling
      return corrected if corrected != query

      correct_model_spelling
    end

    # Получить все подсказки одним вызовом
    def all_suggestions
      {
        autocomplete: autocomplete,
        related: related_searches,
        popular: popular_searches,
        spell_correction: spell_check
      }
    end

    private

    # === Автокомплит по категориям ===

    def brand_suggestions
      return [] if query.blank?

      car_brands = CarBrand.where(is_active: true)
                           .where('LOWER(name) LIKE ?', "#{query}%")
                           .order(:name)
                           .limit(5)
                           .pluck(:name)

      car_brands.map { |b| "#{b}" }
    end

    def model_suggestions
      return [] if query.blank?

      # Ищем модели, соответствующие запросу
      CarModel.joins(:brand)
              .where(is_active: true)
              .where('LOWER(car_models.name) LIKE ?', "#{query}%")
              .order('car_models.name')
              .limit(5)
              .pluck('car_brands.name', 'car_models.name')
              .map { |brand, model| "#{brand} #{model}" }
    end

    def tire_brand_suggestions
      return [] if query.blank?

      TIRE_BRANDS.select { |b| b.downcase.start_with?(query) }
                 .first(3)
    end

    def size_suggestions
      return [] if query.blank?

      # Ищем размеры по диаметру
      if query.match?(/^r?(\d{2})$/i)
        diameter = query.gsub(/[^0-9]/, '').to_i
        return [] unless diameter.between?(13, 24)

        popular_sizes_for_diameter(diameter)
      else
        []
      end
    end

    def popular_sizes_for_diameter(diameter)
      # Популярные размеры для диаметра
      popular = {
        14 => %w[185/65R14 175/70R14 185/60R14],
        15 => %w[195/65R15 185/65R15 205/65R15],
        16 => %w[205/55R16 215/65R16 205/60R16],
        17 => %w[225/45R17 225/55R17 215/55R17],
        18 => %w[235/45R18 225/40R18 235/55R18],
        19 => %w[245/45R19 235/35R19 255/45R19],
        20 => %w[255/45R20 275/45R20 245/40R20]
      }

      popular[diameter] || []
    end

    # === Детекция сущностей в запросе ===

    def detected_brand
      return @detected_brand if defined?(@detected_brand)

      @detected_brand = CarBrand.where(is_active: true)
                                .where('LOWER(name) LIKE ?', "%#{query}%")
                                .first&.name
    end

    def detected_size
      return @detected_size if defined?(@detected_size)

      match = query.match(/(\d{3})\D*(\d{2})\D*r?(\d{2})/i)
      return @detected_size = nil unless match

      @detected_size = {
        width: match[1].to_i,
        height: match[2].to_i,
        diameter: match[3].to_i
      }
    end

    def detected_season
      return @detected_season if defined?(@detected_season)

      @detected_season = case query
                         when /зим|winter/i then 'winter'
                         when /лет|summer/i then 'summer'
                         when /всесез|all.?season/i then 'all_season'
                         end
    end

    # === Related searches helpers ===

    def models_for_brand(brand_name)
      CarModel.joins(:brand)
              .where(is_active: true)
              .where('car_brands.name = ?', brand_name)
              .order(:name)
              .limit(5)
              .pluck(:name)
              .map { |model| "#{brand_name} #{model}" }
    end

    def similar_sizes(size)
      return [] unless size

      width = size[:width]
      diameter = size[:diameter]

      [
        "#{width - 10}/#{size[:height]}R#{diameter}",
        "#{width + 10}/#{size[:height]}R#{diameter}",
        "#{width}/#{size[:height] - 5}R#{diameter}",
        "#{width}/#{size[:height] + 5}R#{diameter}"
      ].select { |s| valid_size_string?(s) }
    end

    def other_seasons(current_season)
      seasons = {
        'winter' => ['Летние шины', 'Всесезонные шины'],
        'summer' => ['Зимние шины', 'Всесезонные шины'],
        'all_season' => ['Зимние шины', 'Летние шины']
      }

      seasons[current_season] || []
    end

    def valid_size_string?(size_str)
      match = size_str.match(/(\d+)\/(\d+)R(\d+)/)
      return false unless match

      width = match[1].to_i
      height = match[2].to_i
      diameter = match[3].to_i

      width.between?(125, 355) && height.between?(25, 85) && diameter.between?(12, 24)
    end

    # === Spell check helpers ===

    def correct_brand_spelling
      return query if query.blank?

      # Проверяем, похож ли запрос на бренд с опечаткой
      brand = find_closest_brand(query)
      brand&.downcase || query
    end

    def correct_model_spelling
      # Базовая реализация - просто возвращаем query
      query
    end

    def find_closest_brand(input)
      return nil if input.blank?

      all_brands = CarBrand.where(is_active: true).pluck(:name)

      # Находим бренд с минимальным расстоянием Левенштейна
      closest = all_brands.min_by do |brand|
        levenshtein_distance(input.downcase, brand.downcase)
      end

      # Возвращаем только если расстояние меньше 3
      return nil if closest.nil?

      distance = levenshtein_distance(input.downcase, closest.downcase)
      distance <= 2 ? closest : nil
    end

    def levenshtein_distance(s1, s2)
      m = s1.length
      n = s2.length

      return m if n.zero?
      return n if m.zero?

      d = Array.new(m + 1) { Array.new(n + 1, 0) }

      (0..m).each { |i| d[i][0] = i }
      (0..n).each { |j| d[0][j] = j }

      (1..m).each do |i|
        (1..n).each do |j|
          cost = s1[i - 1] == s2[j - 1] ? 0 : 1
          d[i][j] = [
            d[i - 1][j] + 1,      # deletion
            d[i][j - 1] + 1,      # insertion
            d[i - 1][j - 1] + cost # substitution
          ].min
        end
      end

      d[m][n]
    end
  end
end
