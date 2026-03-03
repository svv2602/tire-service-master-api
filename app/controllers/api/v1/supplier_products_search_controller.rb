module Api
  module V1
    class SupplierProductsSearchController < ApiController
      skip_after_action :verify_authorized
      skip_before_action :authenticate_request
      
      # POST /api/v1/supplier_products_search
      def search
        search_params = extract_search_params
        
        if search_params.blank?
          return render json: {
            success: false,
            error: 'Параметры поиска не указаны',
            products: []
          }, status: :bad_request
        end
        
        # Кеширование результатов
        cache_key = generate_cache_key(search_params)
        
        results = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
          perform_search(search_params)
        end
        
        render json: results
        
      rescue StandardError => e
        Rails.logger.error "Supplier products search error: #{e.message}"
        render json: {
          success: false,
          error: 'Произошла ошибка при поиске товаров',
          products: []
        }, status: :internal_server_error
      end
      
      # GET /api/v1/supplier_products_search/filters
      def filters
        render json: {
          brands: available_brands,
          seasons: available_seasons,
          diameters: available_diameters,
          size_ranges: {
            width: { min: 125, max: 355 },
            height: { min: 25, max: 95 }
          }
        }
      end
      
      # GET /api/v1/supplier_products_search/product/:id
      def product_details
        product = SupplierTireProduct.includes(:supplier).find(params[:id])
        
        render json: {
          product: format_product_detailed(product)
        }
        
      rescue ActiveRecord::RecordNotFound
        render json: {
          error: 'Товар не найден'
        }, status: :not_found
      end
      
      # GET /api/v1/supplier_products_search/available_sizes/:diameter
      # Получение доступных размеров шин по диаметру из прайсов поставщиков
      # Поддержка фильтрации по конкретным размерам из результатов поиска
      def available_sizes_by_diameter
        diameter = params[:diameter]&.strip
        
        if diameter.blank?
          return render json: {
            success: false,
            error: 'Диаметр не указан',
            sizes: []
          }, status: :bad_request
        end
        
        # Нормализуем диаметр (убираем R если есть)
        normalized_diameter = diameter.gsub(/[^0-9]/, '')
        
        # Получаем фильтры размеров из параметров (если переданы)
        filter_sizes = extract_size_filters
        
        cache_key = generate_sizes_cache_key(normalized_diameter, filter_sizes)
        
        results = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          get_available_sizes_by_diameter(normalized_diameter, filter_sizes)
        end
        
        render json: results
        
      rescue StandardError => e
        Rails.logger.error "Available sizes by diameter error: #{e.message}"
        render json: {
          success: false,
          error: 'Произошла ошибка при получении размеров',
          sizes: []
        }, status: :internal_server_error
      end
      
      # POST /api/v1/supplier_products_search/grouped
      # Поиск с группировкой по параметрам шин (для аккордиона)
      def grouped_search
        search_params = extract_search_params
        
        if search_params.blank?
          return render json: {
            success: false,
            error: 'Параметры поиска не указаны',
            groups: []
          }, status: :bad_request
        end
        
        # Получаем настройку показа всех предложений или только лучших
        show_all_offers = system_setting('show_all_supplier_offers', true)
        
        cache_key = generate_grouped_cache_key(search_params, show_all_offers)
        
        results = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
          perform_grouped_search(search_params, show_all_offers)
        end
        
        render json: results
        
      rescue StandardError => e
        Rails.logger.error "Grouped supplier products search error: #{e.message}"
        render json: {
          success: false,
          error: 'Произошла ошибка при поиске товаров',
          groups: []
        }, status: :internal_server_error
      end
      
      private
      
      def extract_search_params
        {
          brand: params[:brand]&.strip,
          season: normalize_season(params[:season]&.strip),
          width: params[:width]&.to_i,
          height: params[:height]&.to_i,
          diameter: params[:diameter]&.strip,
          min_price: params[:min_price]&.to_f,
          max_price: params[:max_price]&.to_f,
          in_stock_only: params[:in_stock_only] != 'false',
          limit: [params[:limit]&.to_i || 50, 100].min,
          offset: [params[:offset]&.to_i || 0, 0].max
        }.compact
      end
      
      def perform_search(search_params)
        products = SupplierTireProduct.by_search_params(search_params)
                                     .includes(:supplier)
                                     .order(:brand_normalized, :model, :price_uah)
        
        # Применяем ценовые фильтры
        if search_params[:min_price]
          products = products.where('price_uah >= ?', search_params[:min_price])
        end
        
        if search_params[:max_price]
          products = products.where('price_uah <= ?', search_params[:max_price])
        end
        
        # Пагинация
        total_count = products.count
        products = products.limit(search_params[:limit])
                          .offset(search_params[:offset])
        
        {
          success: true,
          products: products.map { |product| format_product(product) },
          total: total_count,
          page_info: {
            limit: search_params[:limit],
            offset: search_params[:offset],
            has_more: (search_params[:offset] + search_params[:limit]) < total_count
          }
        }
      end
      
      def perform_grouped_search(search_params, show_all_offers)
        # Получаем товары по параметрам
        products = SupplierTireProduct.by_search_params(search_params)
                                     .includes(:supplier)
        
        # Применяем ценовые фильтры
        if search_params[:min_price]
          products = products.where('price_uah >= ?', search_params[:min_price])
        end
        
        if search_params[:max_price]
          products = products.where('price_uah <= ?', search_params[:max_price])
        end
        
        # Группируем по параметрам шин
        grouped_products = products.group_by do |product|
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
        
        # Формируем группы для аккордиона
        groups = grouped_products.map do |tire_params, tire_products|
          group_products = if show_all_offers
                            # Показываем все предложения
                            tire_products.sort_by(&:price_uah)
                          else
                            # Показываем только лучшие предложения (по цене и приоритету поставщика)
                            select_best_offers(tire_products)
                          end
          
          {
            tire_key: generate_tire_key(tire_params),
            tire_params: tire_params,
            title: format_tire_title(tire_params),
            suppliers_count: tire_products.map(&:supplier_id).uniq.count,
            products_count: group_products.count,
            price_range: {
              min: group_products.map(&:price_uah).compact.min,
              max: group_products.map(&:price_uah).compact.max
            },
            products: group_products.map { |product| format_product(product) }
          }
        end
        
        # Сортируем группы по релевантности
        groups.sort_by! { |group| [group[:tire_params][:brand], group[:price_range][:min] || Float::INFINITY] }
        
        {
          success: true,
          groups: groups,
          total_groups: groups.count,
          total_products: groups.sum { |g| g[:products_count] },
          show_all_offers: show_all_offers
        }
      end
      
      def select_best_offers(products)
        # Группируем по поставщикам и выбираем лучшие предложения
        by_supplier = products.group_by(&:supplier)
        
        best_offers = by_supplier.map do |supplier, supplier_products|
          # Выбираем самый дешевый товар от каждого поставщика
          best_product = supplier_products.min_by(&:price_uah)
          [supplier.priority, best_product]
        end
        
        # Сортируем по приоритету поставщика и берем топ-3
        best_offers.sort_by(&:first).take(3).map(&:last)
      end
      
      def generate_tire_key(tire_params)
        "#{tire_params[:brand]}_#{tire_params[:model]}_#{tire_params[:width]}_#{tire_params[:height]}_#{tire_params[:diameter]}_#{tire_params[:load_index]}_#{tire_params[:speed_index]}"
      end
      
      def format_tire_title(tire_params)
        size = "#{tire_params[:width]}/#{tire_params[:height]}R#{tire_params[:diameter]}"
        indices = "#{tire_params[:load_index]}#{tire_params[:speed_index]}"
        "#{tire_params[:brand]} #{tire_params[:model]} #{size} #{indices}"
      end
      
      def normalize_season(season)
        return nil if season.blank?
        
        case season.downcase
        when 'winter', 'зима', 'зимние'
          'winter'
        when 'summer', 'лето', 'летние'
          'summer'
        when 'all_season', 'всесезон', 'всесезонные'
          'all_season'
        else
          season
        end
      end
      
      def available_brands
        SupplierTireProduct.in_stock
                          .distinct
                          .pluck(:brand_normalized)
                          .compact
                          .sort
      end
      
      def available_seasons
        [
          { value: 'winter', label: 'Зимние' },
          { value: 'summer', label: 'Летние' },
          { value: 'all_season', label: 'Всесезонные' }
        ]
      end
      
      def available_diameters
        SupplierTireProduct.in_stock
                          .distinct
                          .pluck(:diameter)
                          .compact
                          .map { |d| d.to_s.gsub(/[^0-9]/, '').to_i }
                          .select { |d| d >= 13 && d <= 24 }
                          .uniq
                          .sort
      end
      
      def format_product(product)
        {
          id: product.id,
          external_id: product.external_id,
          supplier: {
            id: product.supplier.id,
            name: product.supplier.name,
            priority: product.supplier.priority
          },
          brand: product.brand_normalized,
          model: product.original_model,
          name: product.name,
          size: product.tire_size,
          load_speed_index: product.load_speed_indices,
          season: product.season,
          season_display: product.season_display,
          price_uah: product.price_uah,
          formatted_price: product.formatted_price,
          stock_status: product.stock_status,
          in_stock: product.in_stock,
          image_url: product.image_url,
          product_url: product.product_url,
          country: product.country,
          year_week: product.year_week
        }
      end
      
      def format_product_detailed(product)
        format_product(product).merge(
          description: product.description,
          raw_data: product.raw_data,
          created_at: product.created_at,
          updated_at: product.updated_at
        )
      end
      
      def generate_cache_key(search_params)
        key_parts = [
          'supplier_products_search',
          Digest::MD5.hexdigest(search_params.to_s),
          SupplierPriceVersion.maximum(:updated_at)&.to_i || 0
        ]
        
        key_parts.join(':')
      end
      
      def generate_grouped_cache_key(search_params, show_all_offers)
        key_parts = [
          'supplier_products_grouped_search',
          Digest::MD5.hexdigest(search_params.to_s),
          show_all_offers ? 'all' : 'best',
          SupplierPriceVersion.maximum(:updated_at)&.to_i || 0
        ]
        
        key_parts.join(':')
      end
      
      def system_setting(key, default_value)
        # TODO: Интеграция с системой настроек из админки
        # SystemSetting.get(key, default_value)
        default_value
      end
      
      def get_available_sizes_by_diameter(diameter, filter_sizes = [])
        # Базовый запрос для размеров шин поставщиков
        query = SupplierTireProduct
                 .in_stock
                 .where(diameter: diameter)
                 .select(:width, :height, :diameter)
        
        # Применяем фильтрацию по конкретным размерам, если переданы
        if filter_sizes.present?
          size_conditions = filter_sizes.map do |size|
            "( width = #{size[:width]} AND height = #{size[:height]} )"
          end.join(' OR ')
          
          query = query.where(size_conditions) if size_conditions.present?
        end
        
        sizes_data = query.distinct.order(:width, :height)
        
        # Группируем и форматируем размеры
        unique_sizes = sizes_data.map do |product|
          {
            width: product.width,
            height: product.height,
            diameter: product.diameter.to_i,
            display: "#{product.width}/#{product.height}R#{product.diameter}",
            size_key: "#{product.width}/#{product.height}R#{product.diameter}"
          }
        end
        
        # Убираем возможные дубли
        unique_sizes = unique_sizes.uniq { |size| size[:size_key] }
        
        {
          success: true,
          diameter: "R#{diameter}",
          sizes: unique_sizes,
          total_sizes: unique_sizes.count,
          data_source: filter_sizes.present? ? 'supplier_prices_filtered' : 'supplier_prices',
          filter_applied: filter_sizes.present?,
          original_sizes_count: filter_sizes.count
        }
      end
      
      def extract_size_filters
        sizes_param = params[:sizes]
        return [] if sizes_param.blank?
        
        # Поддержка разных форматов: JSON строка или comma-separated список
        if sizes_param.is_a?(String)
          if sizes_param.start_with?('[') || sizes_param.start_with?('{')
            # JSON формат: [{"width":205,"height":55},{"width":215,"height":60}]
            begin
              JSON.parse(sizes_param).map do |size|
                {
                  width: size['width']&.to_i,
                  height: size['height']&.to_i
                }
              end.compact.select { |s| s[:width] && s[:height] }
            rescue JSON::ParserError
              []
            end
          else
            # Comma-separated формат: "205/55,215/60,225/50"
            sizes_param.split(',').map do |size|
              parts = size.strip.split('/')
              next unless parts.size == 2
              
              {
                width: parts[0].to_i,
                height: parts[1].to_i
              }
            end.compact.select { |s| s[:width] > 0 && s[:height] > 0 }
          end
        elsif sizes_param.is_a?(Array)
          # Массив хешей из параметров
          sizes_param.map do |size|
            {
              width: size[:width]&.to_i || size['width']&.to_i,
              height: size[:height]&.to_i || size['height']&.to_i
            }
          end.compact.select { |s| s[:width] && s[:height] }
        else
          []
        end
      end
      
      def generate_sizes_cache_key(diameter, filter_sizes)
        base_key = "supplier_sizes_by_diameter:#{diameter}"
        
        if filter_sizes.present?
          sizes_hash = Digest::MD5.hexdigest(filter_sizes.sort_by { |s| [s[:width], s[:height]] }.to_s)
          base_key += ":filtered:#{sizes_hash}"
        end
        
        version = SupplierPriceVersion.maximum(:updated_at)&.to_i || 0
        "#{base_key}:#{version}"
      end
    end
  end
end