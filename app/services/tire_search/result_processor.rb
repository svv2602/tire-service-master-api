# frozen_string_literal: true

module TireSearch
  # ResultProcessor - обработка результатов поиска
  # Отвечает за: пагинацию, форматирование, facets
  class ResultProcessor
    # Константы пагинации
    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 100
    MIN_PAGE = 1

    attr_reader :scope, :options

    def initialize(scope, options = {})
      @scope = scope
      @options = options.with_indifferent_access
    end

    # Главный метод - возвращает обработанные результаты
    def process
      {
        items: formatted_items,
        pagination: pagination_info,
        facets: calculate_facets,
        total_count: total_count
      }
    end

    # Только элементы с пагинацией
    def paginated_items
      @paginated_items ||= scope.limit(per_page).offset(offset)
    end

    # Общее количество результатов
    def total_count
      @total_count ||= scope.count
    end

    private

    # === Форматирование элементов ===

    def formatted_items
      paginated_items.map { |product| format_product(product) }
    end

    def format_product(product)
      {
        id: product.id,
        name: product_name(product),
        brand: product.tire_brand&.name,
        brand_normalized: product.tire_brand&.normalized_name,
        model: product.model,
        size: format_size(product),
        width: product.width,
        height: product.height,
        diameter: product.diameter,
        season: product.season,
        season_display: season_display(product.season),
        price: product.price_uah,
        price_formatted: format_price(product.price_uah),
        quantity: product.quantity,
        in_stock: product.quantity.to_i > 0,
        supplier: product.supplier&.name,
        country: product.country&.name,
        image_url: product.image_url,
        rating: product.rating,
        popularity_score: product.popularity_score,
        specifications: extract_specifications(product),
        created_at: product.created_at
      }
    end

    def product_name(product)
      brand = product.tire_brand&.name || 'Unknown'
      model = product.model || ''
      size = format_size(product)
      "#{brand} #{model} #{size}".strip
    end

    def format_size(product)
      "#{product.width}/#{product.height}R#{product.diameter}"
    end

    def format_price(price)
      return nil unless price

      "#{price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse} грн"
    end

    def season_display(season)
      case season.to_s
      when 'winter' then 'Зимние'
      when 'summer' then 'Летние'
      when 'all_season' then 'Всесезонные'
      else season.to_s.humanize
      end
    end

    def extract_specifications(product)
      {
        load_index: product.load_index,
        speed_index: product.speed_index,
        run_flat: product.run_flat,
        reinforced: product.reinforced,
        noise_level: product.noise_level,
        fuel_efficiency: product.fuel_efficiency,
        wet_grip: product.wet_grip
      }.compact
    end

    # === Пагинация ===

    def pagination_info
      {
        current_page: current_page,
        per_page: per_page,
        total_pages: total_pages,
        total_count: total_count,
        has_next: has_next_page?,
        has_previous: has_previous_page?,
        next_page: has_next_page? ? current_page + 1 : nil,
        previous_page: has_previous_page? ? current_page - 1 : nil
      }
    end

    def current_page
      @current_page ||= [options[:page].to_i, MIN_PAGE].max
    end

    def per_page
      @per_page ||= begin
        requested = options[:per_page].to_i
        requested = DEFAULT_PAGE_SIZE if requested <= 0
        [requested, MAX_PAGE_SIZE].min
      end
    end

    def offset
      (current_page - 1) * per_page
    end

    def total_pages
      return 0 if total_count.zero?

      (total_count.to_f / per_page).ceil
    end

    def has_next_page?
      current_page < total_pages
    end

    def has_previous_page?
      current_page > MIN_PAGE
    end

    # === Facets ===

    def calculate_facets
      return {} unless options[:include_facets]

      {
        brands: brand_facets,
        seasons: season_facets,
        widths: width_facets,
        heights: height_facets,
        diameters: diameter_facets,
        price_range: price_range_facet
      }
    end

    def brand_facets
      scope.joins(:tire_brand)
           .group('tire_brands.name')
           .order('count_all DESC')
           .limit(20)
           .count
           .map { |name, count| { name: name, count: count } }
    end

    def season_facets
      scope.group(:season)
           .count
           .map do |season, count|
        {
          value: season,
          label: season_display(season),
          count: count
        }
      end
    end

    def width_facets
      scope.group(:width)
           .order(:width)
           .count
           .map { |width, count| { value: width, count: count } }
    end

    def height_facets
      scope.group(:height)
           .order(:height)
           .count
           .map { |height, count| { value: height, count: count } }
    end

    def diameter_facets
      scope.group(:diameter)
           .order(:diameter)
           .count
           .map { |diameter, count| { value: diameter, count: count } }
    end

    def price_range_facet
      stats = scope.pluck(
        Arel.sql('MIN(price_uah)'),
        Arel.sql('MAX(price_uah)'),
        Arel.sql('AVG(price_uah)')
      ).first

      return {} unless stats&.any?

      {
        min: stats[0]&.to_i,
        max: stats[1]&.to_i,
        avg: stats[2]&.to_i
      }
    end
  end
end
