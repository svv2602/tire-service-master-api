# frozen_string_literal: true

module TireChat
  # Adapter for TireSearchService interaction
  # Provides tire search capabilities for chat context
  class SearchAdapter
    MAX_RESULTS_FOR_CHAT = 5
    MAX_PRODUCTS_FOR_GROUPING = 200
    MAX_PRODUCTS_FOR_PRICE_ANALYSIS = 500

    attr_reader :filters, :user_preferences

    def initialize(filters: {}, user_preferences: {})
      @filters = filters
      @user_preferences = user_preferences
    end

    # Search tires based on current filters
    # @param available_products [ActiveRecord::Relation, nil] Optional pre-filtered scope
    # @return [Array<Hash>] Recommendation items with products and scores
    def search_from_context(available_products = nil)
      Rails.logger.info "🔍 SearchAdapter: поиск с фильтрами: #{@filters}"

      products_scope = available_products || base_scope
      products_scope = apply_filters(products_scope)

      all_products = products_scope.limit(MAX_PRODUCTS_FOR_GROUPING)
      return [] if all_products.count.zero?

      grouped_products = group_products_by_tire_params(all_products)
      Rails.logger.info "🔄 Создано #{grouped_products.count} групп уникальных шин"

      calculate_recommendations(grouped_products)
    end

    # Search tires by vehicle model (placeholder for integration with vehicle service)
    # @param vehicle [String] Vehicle make/model
    # @return [Array<Hash>] Compatible tire recommendations
    def search_by_vehicle(vehicle)
      Rails.logger.info "🚗 SearchAdapter: поиск по автомобилю: #{vehicle}"
      # This would integrate with a vehicle compatibility service
      []
    end

    # Search tires by specific size
    # @param width [Integer] Tire width
    # @param height [Integer] Tire profile height
    # @param diameter [Integer] Rim diameter
    # @return [Array<Hash>] Matching tire recommendations
    def search_by_size(width, height, diameter)
      products_scope = base_scope.by_size(width, height, diameter)
      apply_season_filter(products_scope)
    end

    # Get detailed information about specific tire
    # @param product_id [Integer] Product ID
    # @return [Hash, nil] Tire details
    def get_tire_details(product_id)
      product = SupplierTireProduct.find_by(id: product_id)
      return nil unless product

      {
        product: product,
        brand: product.brand_normalized,
        model: product.original_model,
        size: "#{product.width}/#{product.height}R#{product.diameter}",
        price: product.price_uah,
        season: product.season,
        country: product.country&.name,
        supplier: product.supplier&.name
      }
    end

    # Get price segment recommendations
    # @param price_segment [String] Price segment (premium, middle, budget)
    # @param available_products [ActiveRecord::Relation, nil] Optional pre-filtered scope
    # @return [Array<Hash>] Recommendations for specified price segment
    def get_price_segment_recommendations(price_segment, available_products = nil)
      Rails.logger.info "💰 SearchAdapter: поиск по ценовому сегменту: #{price_segment}"

      products_scope = available_products || base_scope
      products_scope = apply_filters(products_scope)

      all_products = products_scope.limit(MAX_PRODUCTS_FOR_PRICE_ANALYSIS)
      return [] if all_products.count.zero?

      grouped_products = group_products_by_tire_params(all_products)
      Rails.logger.info "🔄 Создано #{grouped_products.count} групп для ценового анализа"

      return sort_by_price_segment(grouped_products, price_segment) if grouped_products.count <= MAX_RESULTS_FOR_CHAT

      filter_by_price_segment(grouped_products, price_segment)
    end

    private

    def base_scope
      SupplierTireProduct.in_stock.includes(:tire_brand, :tire_model, :country, :supplier)
    end

    def apply_filters(scope)
      scope = apply_size_filter(scope)
      scope = apply_season_filter(scope)
      apply_brand_filter(scope)
    end

    def apply_size_filter(scope)
      return scope unless @filters[:size].present?

      size = @filters[:size]
      Rails.logger.info "📏 Применяю фильтр размера: #{size[:width]}/#{size[:height]}R#{size[:diameter]}"
      filtered = scope.by_size(size[:width], size[:height], size[:diameter])
      Rails.logger.info "📏 После фильтра размера: #{filtered.count} товаров"
      filtered
    end

    def apply_season_filter(scope)
      return scope unless @filters[:season].present?

      Rails.logger.info "❄️ Применяю фильтр сезона: #{@filters[:season]}"
      filtered = scope.by_season(@filters[:season])
      Rails.logger.info "❄️ После фильтра сезона: #{filtered.count} товаров"
      filtered
    end

    def apply_brand_filter(scope)
      return scope unless @filters[:brands].present?

      brand_ids = TireBrand.where(normalized_name: @filters[:brands]).pluck(:id)
      scope.where(tire_brand_id: brand_ids)
    end

    # Group products by unique tire parameters
    def group_products_by_tire_params(products)
      grouped = products.group_by do |product|
        {
          brand: product.brand_normalized,
          model: product.original_model,
          width: product.width,
          height: product.height,
          diameter: product.diameter,
          load_index: product.load_index,
          speed_index: product.speed_index,
          season: product.season
        }
      end

      grouped.map do |tire_params, tire_products|
        cheapest_product = tire_products.min_by { |p| p.price_uah || Float::INFINITY }

        {
          tire_params: tire_params,
          best_product: cheapest_product,
          all_products: tire_products,
          suppliers_count: tire_products.map(&:supplier_id).uniq.count,
          price_range: {
            min: tire_products.map(&:price_uah).compact.min,
            max: tire_products.map(&:price_uah).compact.max
          }
        }
      end
    end

    # Calculate recommendations with optimality scores
    def calculate_recommendations(grouped_products)
      priority_type = @user_preferences[:priority_type] || 'balanced'

      recommendations = grouped_products.map do |group|
        product = group[:best_product]
        optimality_result = calculate_optimality(product, priority_type)

        build_recommendation(group, optimality_result)
      end

      sort_and_limit_recommendations(recommendations)
    rescue StandardError => e
      Rails.logger.error "❌ Ошибка при расчете оптимальности: #{e.message}"
      fallback_recommendations(grouped_products)
    end

    def calculate_optimality(product, priority_type)
      TireOptimalityCalculator.calculate_batch_optimality(
        [product],
        priority_type: priority_type
      ).first
    end

    def build_recommendation(group, optimality_result)
      product = group[:best_product]
      score = optimality_result ? optimality_result[:optimality_score] : 7.0
      reasons = optimality_result ? optimality_result[:recommendation_reasons] : ['Доступен в наличии']

      reasons << "Доступен у #{group[:suppliers_count]} поставщиков" if group[:suppliers_count] > 1

      if group[:price_range][:min] && group[:price_range][:max] &&
         group[:price_range][:max] > group[:price_range][:min]
        savings = group[:price_range][:max] - group[:price_range][:min]
        reasons << "Экономия до #{savings.to_i} грн по сравнению с другими поставщиками"
      end

      {
        product: product,
        optimality_score: score,
        recommendation_reasons: reasons,
        tire_group_info: group[:tire_params],
        suppliers_count: group[:suppliers_count],
        price_savings: calculate_savings(group)
      }
    end

    def calculate_savings(group)
      return 0 unless group[:price_range][:max]

      (group[:price_range][:max] - group[:price_range][:min]).to_i
    end

    def sort_and_limit_recommendations(recommendations)
      recommendations.sort_by! do |rec|
        [-rec[:optimality_score], rec[:product].price_uah || Float::INFINITY]
      end

      recommendations.first(MAX_RESULTS_FOR_CHAT)
    end

    def fallback_recommendations(grouped_products)
      grouped_products.sort_by { |group| group[:best_product].price_uah || Float::INFINITY }
                      .first(MAX_RESULTS_FOR_CHAT)
                      .map do |group|
        {
          product: group[:best_product],
          optimality_score: 7.0,
          recommendation_reasons: ['Доступен в наличии', 'Лучшая цена в категории'],
          tire_group_info: group[:tire_params],
          suppliers_count: group[:suppliers_count],
          price_savings: calculate_savings(group)
        }
      end
    end

    # Filter products by price segment
    def filter_by_price_segment(grouped_products, price_segment)
      prices = grouped_products.map { |g| g[:best_product].price_uah }.compact
      min_price = prices.min
      max_price = prices.max
      delta = (max_price - min_price) / 3.0

      Rails.logger.info "💰 Ценовые диапазоны: min=#{min_price}, max=#{max_price}, delta=#{delta}"

      filtered_groups = filter_groups_by_segment(grouped_products, price_segment, min_price, max_price, delta)
      Rails.logger.info "🎯 Отфильтровано #{filtered_groups.count} групп для сегмента #{price_segment}"

      build_price_segment_recommendations(filtered_groups.first(MAX_RESULTS_FOR_CHAT), price_segment)
    end

    def filter_groups_by_segment(grouped_products, segment, min_price, max_price, delta)
      case segment
      when 'premium'
        grouped_products.select { |g| g[:best_product].price_uah >= (max_price - delta) }
                        .sort_by { |g| -g[:best_product].price_uah }
      when 'budget'
        grouped_products.select { |g| g[:best_product].price_uah <= (min_price + delta) }
                        .sort_by { |g| g[:best_product].price_uah }
      when 'middle'
        grouped_products.select do |g|
          price = g[:best_product].price_uah
          price >= (min_price + delta) && price <= (max_price - delta)
        end.sort_by { |g| -g[:best_product].price_uah }
      else
        grouped_products
      end
    end

    def sort_by_price_segment(grouped_products, price_segment)
      sorted = case price_segment
               when 'premium'
                 grouped_products.sort_by { |g| -g[:best_product].price_uah }
               when 'budget'
                 grouped_products.sort_by { |g| g[:best_product].price_uah }
               else
                 grouped_products.sort_by { |g| -g[:best_product].price_uah }
               end

      build_price_segment_recommendations(sorted, price_segment)
    end

    def build_price_segment_recommendations(groups, price_segment)
      groups.map do |group|
        {
          product: group[:best_product],
          optimality_score: 8.0,
          recommendation_reasons: price_segment_reasons(price_segment, group),
          tire_group_info: group[:tire_params],
          suppliers_count: group[:suppliers_count],
          price_savings: calculate_savings(group)
        }
      end
    end

    def price_segment_reasons(segment, group)
      reasons = case segment
                when 'premium'
                  ['Премиум качество', 'Высокие характеристики']
                when 'budget'
                  ['Лучшая цена', 'Экономичный выбор']
                when 'middle'
                  ['Оптимальное соотношение цена/качество', 'Средний ценовой сегмент']
                else
                  []
                end

      reasons << "Доступен у #{group[:suppliers_count]} поставщиков" if group[:suppliers_count] > 1

      if group[:price_range][:max] && group[:price_range][:min] &&
         group[:price_range][:max] > group[:price_range][:min]
        savings = group[:price_range][:max] - group[:price_range][:min]
        reasons << "Экономия до #{savings.to_i} грн"
      end

      reasons
    end
  end
end
