module Api
  module V1
    class TireSearchController < ApiController
      skip_before_action :authenticate_request, only: [:search, :suggestions, :popular, :brands, :models, :diameters]
      
      # POST /api/v1/tire_search
      def search
        query = params[:query].to_s.strip
        
        if query.blank?
          locale = detect_locale
          I18n.with_locale(locale) do
            render json: { 
              error: I18n.t('tire_search.messages.empty_query'),
              suggestions: TireSearchService::SearchStats.popular_queries
            }, status: :bad_request
          end
          return
        end
        
        # Определяем локаль из заголовков или параметров
        locale = detect_locale
        Rails.logger.info "TireSearchController: Detected locale: #{locale}"
        Rails.logger.info "TireSearchController: Request params: #{params.inspect}"
        Rails.logger.info "TireSearchController: Accept-Language header: #{request.headers['Accept-Language']}"
        
        # Опции поиска
        search_options = {
          limit: [params[:limit].to_i, 50].min.positive? ? [params[:limit].to_i, 50].min : 20,
          offset: [params[:offset].to_i, 0].max,
          use_llm: params[:use_llm] != 'false',
          locale: locale
        }
        
        # Кешируем популярные запросы (включаем локаль в ключ кеша)
        cache_key = generate_cache_key(query, search_options)
        
        results = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          Rails.logger.info "Creating TireSearchService with query: '#{query}', options: #{search_options.inspect}"
          service = TireSearchService.new(query, search_options)
          result = service.search
          Rails.logger.info "Service returned: total=#{result[:total]}, parsed_data=#{result[:parsed_data].inspect}"
          result
        end
        
        # Записываем статистику
        TireSearchService::SearchStats.record_search(
          query, 
          results[:total], 
          results[:parsed_data]
        )
        
        # Новый формат ответа для первого этапа поиска
        render json: {
          success: results[:success],
          message: results[:message],
          tire_sizes: results[:tire_sizes],
          tire_brands: results[:tire_brands],
          seasonality: results[:seasonality],
          car_info: results[:car_info],
          query: results[:query],
          parsed_data: results[:parsed_data],
          suggestions: results[:suggestions],
          warnings: results[:warnings]
        }
        
      rescue => e
        Rails.logger.error "Tire search error: #{e.message}"
        render json: { 
          error: 'Произошла ошибка при поиске шин',
          suggestions: TireSearchService::SearchStats.popular_queries
        }, status: :internal_server_error
      end
      
      # GET /api/v1/tire_search/suggestions
      def suggestions
        query = params[:query].to_s.strip
        
        if query.length < 2
          render json: { suggestions: [] }
          return
        end
        
        # Поиск предложений в базе данных
        suggestions = generate_suggestions(query)
        
        render json: { suggestions: suggestions }
      end
      
      # GET /api/v1/tire_search/popular
      def popular
        limit = [params[:limit].to_i, 20].min.positive? ? [params[:limit].to_i, 20].min : 10
        
        popular_queries = TireSearchService::SearchStats.popular_queries(limit)
        
        render json: { 
          popular_queries: popular_queries,
          total: popular_queries.size
        }
      end
      
      # GET /api/v1/tire_search/brands
      def brands
        brands = CarBrand.active
                         .joins(:car_tire_configurations)
                         .distinct
                         .order(:name)
                         .limit(50)
        
        render json: {
          brands: brands.map { |brand| { id: brand.id, name: brand.name } }
        }
      end
      
      # GET /api/v1/tire_search/models
      def models
        brand_id = params[:brand_id]
        
        scope = CarModel.active.joins(:car_tire_configurations).distinct
        scope = scope.where(brand_id: brand_id) if brand_id.present?
        
        models = scope.includes(:brand).order(:name).limit(100)
        
        render json: {
          models: models.map do |model|
            {
              id: model.id,
              name: model.name,
              brand: { id: model.brand.id, name: model.brand.name }
            }
          end
        }
      end
      
      # GET /api/v1/tire_search/diameters
      def diameters
        # Извлекаем уникальные диаметры из всех конфигураций
        diameters_query = <<-SQL
          SELECT DISTINCT (jsonb_array_elements(tire_sizes)->>'diameter')::integer as diameter
          FROM car_tire_configurations
          WHERE is_active = true AND is_deprecated = false
          ORDER BY (jsonb_array_elements(tire_sizes)->>'diameter')::integer
        SQL
        
        diameters = ActiveRecord::Base.connection.execute(diameters_query)
                                     .map { |row| row['diameter'].to_i }
                                     .select { |d| d >= 13 && d <= 24 }
                                     .uniq
                                     .sort
        
        render json: { diameters: diameters }
      end
      
      # GET /api/v1/tire_search/statistics
      def statistics
        authorize_admin_or_render_unauthorized and return
        
        stats = {
          total_configurations: CarTireConfiguration.active.not_deprecated.count,
          total_brands: CarBrand.joins(:car_tire_configurations).distinct.count,
          total_models: CarModel.joins(:car_tire_configurations).distinct.count,
          current_version: TireDataVersion.current&.version,
          last_update: TireDataVersion.current&.imported_at,
          version_info: TireDataVersion.version_statistics
        }
        
        render json: stats
      end
      
      private
      
      def generate_cache_key(query, options)
        key_parts = [
          'tire_search',
          Digest::MD5.hexdigest(query.downcase),
          options[:limit],
          options[:offset],
          options[:use_llm] ? 'llm' : 'simple',
          options[:locale] || 'ru',
          TireDataVersion.current&.version || 'default'
        ]
        
        key_parts.join(':')
      end
      
      def generate_suggestions(query)
        query_lower = query.downcase
        suggestions = []
        
        # Поиск брендов
        matching_brands = CarBrand.active
                                  .joins(:car_tire_configurations)
                                  .where("LOWER(name) LIKE ?", "#{query_lower}%")
                                  .distinct
                                  .limit(5)
                                  .pluck(:name)
        
        suggestions.concat(matching_brands)
        
        # Поиск моделей
        matching_models = CarModel.active
                                  .joins(:car_tire_configurations, :brand)
                                  .where("LOWER(car_models.name) LIKE ? OR LOWER(car_brands.name) LIKE ?", 
                                         "#{query_lower}%", "#{query_lower}%")
                                  .distinct
                                  .limit(5)
                                  .includes(:brand)
        
        matching_models.each do |model|
          suggestions << "#{model.brand.name} #{model.name}"
        end
        
        # Поиск по токенам
        token_matches = CarTireConfiguration.active
                                           .not_deprecated
                                           .where("search_tokens ILIKE ?", "%#{query_lower}%")
                                           .includes(:brand, :model)
                                           .limit(3)
        
        token_matches.each do |config|
          suggestions << config.full_name
        end
        
        # Убираем дубликаты и ограничиваем количество
        suggestions.uniq.take(10)
      end
      
      def authorize_admin_or_render_unauthorized
        unless current_user&.admin?
          render json: { error: 'Доступ запрещен' }, status: :forbidden
          return false
        end
        true
      end
      
      def detect_locale
        # Приоритет: параметр locale, заголовок Accept-Language, язык пользователя, по умолчанию
        locale = params[:locale]
        
        if locale.blank?
          # Проверяем заголовок Accept-Language
          accept_language = request.headers['Accept-Language']
          if accept_language.present?
            # Ищем поддерживаемые локали (uk, ru)
            if accept_language.include?('uk')
              locale = 'uk'
            elsif accept_language.include?('ru')
              locale = 'ru'
            end
          end
        end
        
        # Если есть авторизованный пользователь, используем его предпочтения
        if locale.blank? && current_user&.language.present?
          locale = current_user.language
        end
        
        # По умолчанию русский
        locale.presence || 'ru'
      end
    end
  end
end