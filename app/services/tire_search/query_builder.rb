# frozen_string_literal: true

module TireSearch
  # QueryBuilder - построение ActiveRecord запросов для поиска шин
  # Отвечает за: фильтры, сортировку, текстовый поиск
  class QueryBuilder
    # Константы для валидации размеров шин
    VALID_WIDTH_RANGE = (125..355).freeze
    VALID_HEIGHT_RANGE = (25..85).freeze
    VALID_DIAMETER_RANGE = (12..24).freeze

    # Сортировки
    SORT_OPTIONS = %w[price name popularity rating created_at].freeze
    DEFAULT_SORT = 'popularity'
    DEFAULT_ORDER = 'desc'

    attr_reader :params, :scope

    def initialize(params = {})
      @params = params.with_indifferent_access
      @scope = base_scope
    end

    # Главный метод - строит и возвращает scope
    def build
      apply_size_filters
      apply_brand_filter
      apply_season_filter
      apply_price_filter
      apply_stock_filter
      apply_text_search
      apply_sorting
      @scope
    end

    # Базовый scope
    def base_scope
      SupplierTireProduct.available.includes(:tire_brand, :supplier, :country)
    end

    private

    # === Фильтры размеров ===

    def apply_size_filters
      apply_width_filter
      apply_height_filter
      apply_diameter_filter
      apply_full_size_filter
    end

    def apply_width_filter
      return unless params[:width].present?

      width = params[:width].to_i
      return unless VALID_WIDTH_RANGE.include?(width)

      @scope = @scope.where(width: width)
    end

    def apply_height_filter
      return unless params[:height].present?

      height = params[:height].to_i
      return unless VALID_HEIGHT_RANGE.include?(height)

      @scope = @scope.where(height: height)
    end

    def apply_diameter_filter
      return unless params[:diameter].present?

      diameter = params[:diameter].to_i
      return unless VALID_DIAMETER_RANGE.include?(diameter)

      @scope = @scope.where(diameter: diameter)
    end

    def apply_full_size_filter
      return unless params[:tire_size].is_a?(Hash)

      size = params[:tire_size]
      width = size[:width].to_i
      height = size[:height].to_i
      diameter = size[:diameter].to_i

      return unless valid_full_size?(width, height, diameter)

      @scope = @scope.where(width: width, height: height, diameter: diameter)
    end

    def valid_full_size?(width, height, diameter)
      VALID_WIDTH_RANGE.include?(width) &&
        VALID_HEIGHT_RANGE.include?(height) &&
        VALID_DIAMETER_RANGE.include?(diameter)
    end

    # === Фильтр бренда ===

    def apply_brand_filter
      return unless params[:tire_brands].present?

      brands = Array(params[:tire_brands]).map(&:downcase)
      return if brands.empty?

      @scope = @scope.joins(:tire_brand)
                     .where('LOWER(tire_brands.normalized_name) IN (?)', brands)
    end

    # === Фильтр сезона ===

    def apply_season_filter
      return unless params[:seasonality].present?

      season = normalize_season(params[:seasonality])
      return unless season.present?

      @scope = @scope.where(season: season)
    end

    def normalize_season(season)
      case season.to_s.downcase
      when 'winter', 'зимние', 'зима'
        'winter'
      when 'summer', 'летние', 'лето'
        'summer'
      when 'all_season', 'всесезонные', 'всесезон'
        'all_season'
      else
        season
      end
    end

    # === Фильтр цены ===

    def apply_price_filter
      apply_min_price_filter
      apply_max_price_filter
      apply_price_segment_filter
    end

    def apply_min_price_filter
      return unless params[:price_min].present?

      min_price = params[:price_min].to_f
      return unless min_price > 0

      @scope = @scope.where('price_uah >= ?', min_price)
    end

    def apply_max_price_filter
      return unless params[:price_max].present?

      max_price = params[:price_max].to_f
      return unless max_price > 0

      @scope = @scope.where('price_uah <= ?', max_price)
    end

    def apply_price_segment_filter
      return unless params[:price_segment].present?

      case params[:price_segment].to_s
      when 'budget'
        @scope = @scope.where('price_uah < ?', budget_threshold)
      when 'middle'
        @scope = @scope.where('price_uah >= ? AND price_uah <= ?', budget_threshold, premium_threshold)
      when 'premium'
        @scope = @scope.where('price_uah > ?', premium_threshold)
      end
    end

    def budget_threshold
      @budget_threshold ||= calculate_price_percentile(33)
    end

    def premium_threshold
      @premium_threshold ||= calculate_price_percentile(66)
    end

    def calculate_price_percentile(percentile)
      # Упрощенный расчет на основе средней цены
      avg_price = SupplierTireProduct.available.average(:price_uah) || 3000
      case percentile
      when 33 then avg_price * 0.7
      when 66 then avg_price * 1.3
      else avg_price
      end
    end

    # === Фильтр наличия ===

    def apply_stock_filter
      return unless params[:in_stock].present?

      if params[:in_stock].to_s == 'true' || params[:in_stock] == true
        @scope = @scope.where('quantity > 0')
      end
    end

    # === Текстовый поиск ===

    def apply_text_search
      return unless params[:query].present?

      query = params[:query].to_s.strip
      return if query.blank?

      search_term = "%#{sanitize_search_term(query)}%"

      @scope = @scope.joins(:tire_brand)
                     .where(
                       'tire_brands.name ILIKE ? OR tire_brands.normalized_name ILIKE ? OR supplier_tire_products.model ILIKE ?',
                       search_term, search_term, search_term
                     )
    end

    def sanitize_search_term(term)
      term.gsub(/[%_\\]/) { |char| "\\#{char}" }
    end

    # === Сортировка ===

    def apply_sorting
      sort_field = validated_sort_field
      sort_order = validated_sort_order

      @scope = case sort_field
               when 'price'
                 @scope.order(price_uah: sort_order)
               when 'name'
                 @scope.joins(:tire_brand).order('tire_brands.name' => sort_order, model: sort_order)
               when 'popularity'
                 @scope.order(popularity_score: sort_order)
               when 'rating'
                 @scope.order(rating: sort_order)
               when 'created_at'
                 @scope.order(created_at: sort_order)
               else
                 @scope.order(popularity_score: :desc)
               end
    end

    def validated_sort_field
      field = params[:sort].to_s
      SORT_OPTIONS.include?(field) ? field : DEFAULT_SORT
    end

    def validated_sort_order
      params[:order].to_s.downcase == 'asc' ? :asc : :desc
    end
  end
end
