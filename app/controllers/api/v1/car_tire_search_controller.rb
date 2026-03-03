# frozen_string_literal: true

# Контроллер для поиска шин по автомобилю
class Api::V1::CarTireSearchController < ApplicationController
  skip_after_action :verify_authorized
  skip_before_action :authenticate_request  # Публичный API
  before_action :set_locale

  # POST /api/v1/car_tire_search/search
  # Поиск шин по автомобилю с учетом неоднозначности брендов
  def search
    query = params[:query]&.strip
    
    if query.blank?
      render json: { 
        error: 'Поисковый запрос не может быть пустым',
        status: :empty 
      }, status: :bad_request
      return
    end

    # Парсим запрос на составляющие
    parsed_query = parse_vehicle_query(query)
    
    # Ищем бренды автомобилей
    brand_result = CarBrandSearchService.search(parsed_query[:brand])
    
    case brand_result[:status]
    when :not_found
      render json: {
        status: :brand_not_found,
        message: "Марка автомобиля \"#{parsed_query[:brand]}\" не найдена",
        suggestions: get_brand_suggestions(parsed_query[:brand])
      }
      
    when :multiple
      render json: {
        status: :brand_ambiguous,
        message: "Найдено несколько марок автомобилей. Уточните выбор:",
        brands: brand_result[:brands],
        query: parsed_query
      }
      
    when :exact
      # Найден единственный бренд, ищем модели
      brand = brand_result[:brands].first
      search_models_and_sizes(brand, parsed_query)
      
    else
      render json: { 
        error: 'Неизвестная ошибка поиска',
        status: :error 
      }, status: :internal_server_error
    end
  end

  # POST /api/v1/car_tire_search/resolve_brand
  # Разрешение неоднозначности брендов
  def resolve_brand
    brand_id = params[:brand_id]
    query = params[:query]
    
    if brand_id.blank? || query.blank?
      render json: { error: 'Параметры brand_id и query обязательны' }, status: :bad_request
      return
    end

    brand = CarBrand.find_by(id: brand_id)
    unless brand
      render json: { error: 'Бренд не найден' }, status: :not_found
      return
    end

    parsed_query = parse_vehicle_query(query)
    search_models_and_sizes(format_brand(brand), parsed_query)
  end

  # POST /api/v1/car_tire_search/resolve_model
  # Получение размеров шин для конкретной модели
  def resolve_model
    model_id = params[:model_id]
    year = params[:year]&.to_i
    
    if model_id.blank?
      render json: { 
        status: 'error', 
        message: 'ID модели обязателен' 
      }, status: :bad_request
      return
    end
    
    begin
      model = CarModel.includes(:brand).find(model_id)
      brand = format_brand(model.brand)
      
      # Ищем размеры шин для модели
      tire_sizes = CarBrandSearchService.get_tire_sizes(model_id, year)
      
      if tire_sizes.empty?
        render json: {
          status: :sizes_not_found,
          message: "Размеры шин не найдены для #{brand[:name]} #{model.name}#{year ? " #{year} года" : ""}",
          brand: brand,
          model: {
            id: model.id,
            name: model.name,
            brand_name: brand[:name],
            brand_id: brand[:id]
          },
          year: year
        }
        return
      end
      
      # Ищем товары поставщиков для найденных размеров
      tire_offers = find_tire_offers(tire_sizes)
      
      render json: {
        status: :success,
        brand: brand,
        model: {
          id: model.id,
          name: model.name,
          brand_name: brand[:name],
          brand_id: brand[:id]
        },
        year: year,
        tire_sizes: tire_sizes,
        tire_offers: tire_offers,
        message: "Найдено #{tire_sizes.count} размеров шин и #{tire_offers.count} предложений"
      }
      
    rescue ActiveRecord::RecordNotFound
      render json: { 
        status: 'error', 
        message: 'Модель автомобиля не найдена' 
      }, status: :not_found
    rescue => e
      Rails.logger.error "Car tire search error: #{e.message}"
      render json: { 
        status: 'error', 
        message: 'Ошибка при поиске размеров шин' 
      }, status: :internal_server_error
    end
  end

  private

  # Парсинг поискового запроса автомобиля
  def parse_vehicle_query(query)
    result = {
      brand: '',
      model: '',
      year: nil,
      original_query: query,
      llm_used: false,
      llm_confidence: 0.0
    }
    
    # Проверяем, нужен ли LLM для данного запроса
    car_llm_service = CarSearchLlmService.new
    
    if car_llm_service.needs_llm?(query)
      Rails.logger.info "CarTireSearch: Using LLM for complex query: '#{query}'"
      
      # Используем LLM для обработки сложного запроса
      llm_result = car_llm_service.parse_car_query(query)
      
      if llm_result[:confidence] && llm_result[:confidence] > 0.5
        result[:brand] = llm_result[:brand] if llm_result[:brand].present?
        result[:model] = llm_result[:model] if llm_result[:model].present?
        result[:year] = llm_result[:year] if llm_result[:year] && llm_result[:year] > 0
        result[:llm_used] = true
        result[:llm_confidence] = llm_result[:confidence]
        result[:llm_reasoning] = llm_result[:reasoning]
        
        Rails.logger.info "CarTireSearch: LLM success with confidence #{llm_result[:confidence]}: brand='#{result[:brand]}', model='#{result[:model]}'"
      else
        Rails.logger.warn "CarTireSearch: LLM confidence too low (#{llm_result[:confidence]}), falling back to regex parsing"
      end
    end
    
    # Если LLM не использовался или дал низкую уверенность, используем TireSearchService
    if result[:brand].blank? || result[:model].blank?
      Rails.logger.info "CarTireSearch: Using regex parsing for query: '#{query}'"
      
      tire_service = TireSearchService.new(query, { locale: 'ru' })
      parsed_data = tire_service.send(:parse_simple_query)
      
      result[:brand] = parsed_data[:brand] if parsed_data[:brand].present? && result[:brand].blank?
      result[:model] = parsed_data[:model] if parsed_data[:model].present? && result[:model].blank?
    end
    
    # Ищем год (если не найден через LLM)
    if result[:year].nil?
      year_match = query.match(/\b(19[8-9]\d|20[0-3]\d)\b/)
      result[:year] = year_match[1].to_i if year_match
    end
    
    Rails.logger.info "CarTireSearch: Final result for '#{query}' -> brand: '#{result[:brand]}', model: '#{result[:model]}', year: #{result[:year]}, llm_used: #{result[:llm_used]}"
    
    result
  end

  # Поиск моделей и размеров шин
  def search_models_and_sizes(brand, parsed_query)
    if parsed_query[:model].present?
      # Если модель найдена через LLM, ищем её напрямую в базе
      if parsed_query[:llm_used]
        # LLM уже дал нам точное название модели, ищем его в БД
        exact_models = CarModel.where(brand_id: brand[:id])
                              .where('name = ?', parsed_query[:model])
                              .includes(:brand)
        
        if exact_models.any?
          models = exact_models.map do |model|
            {
              id: model.id,
              name: model.name,
              brand_name: model.brand.name,
              brand_id: model.brand_id,
              configs_count: CarTireConfiguration.where(model_id: model.id).count
            }
          end
        else
          # Если точного совпадения нет, пробуем частичный поиск
          models = CarBrandSearchService.search_models([brand[:id]], parsed_query[:model])
        end
      else
        # Используем старую логику с алиасами для regex-парсинга
        model_query = parsed_query[:model]
        
        # Если в оригинальном запросе есть модификации двигателя, учитываем их
        original_lower = parsed_query[:original_query].downcase
        if original_lower.match?(/\b\d{3,4}[a-zа-я]*\b/) # например, 450d, 300, 63s, 450д
          # Извлекаем часть запроса после бренда для поиска модели с модификацией
          brand_pattern = /\b#{Regexp.escape(brand[:name].downcase)}\b/
          if original_lower.match?(brand_pattern)
            after_brand = original_lower.split(brand_pattern, 2).last&.strip
            model_query = after_brand if after_brand.present?
          end
        end
        
        models = CarBrandSearchService.search_models([brand[:id]], model_query)
      end
      
      if models.empty?
        render json: {
          status: :model_not_found,
          message: "Модель \"#{parsed_query[:model]}\" не найдена для марки #{brand[:name]}",
          brand: brand,
          available_models: get_popular_models(brand[:id])
        }
        return
      end
      
      if models.size > 1
        render json: {
          status: :model_ambiguous,
          message: "Найдено несколько моделей. Уточните выбор:",
          brand: brand,
          models: models,
          query: parsed_query
        }
        return
      end
      
      # Найдена единственная модель, ищем размеры шин
      model = models.first
      tire_sizes = CarBrandSearchService.get_tire_sizes(model[:id], parsed_query[:year])
      
      if tire_sizes.empty?
        render json: {
          status: :sizes_not_found,
          message: "Размеры шин не найдены для #{brand[:name]} #{model[:name]}#{parsed_query[:year] ? " #{parsed_query[:year]} года" : ""}",
          brand: brand,
          model: model,
          year: parsed_query[:year]
        }
        return
      end
      
      # Ищем товары поставщиков для найденных размеров
      tire_offers = find_tire_offers(tire_sizes)
      
      render json: {
        status: :success,
        brand: brand,
        model: model,
        year: parsed_query[:year],
        tire_sizes: tire_sizes,
        tire_offers: tire_offers,
        message: "Найдено #{tire_sizes.count} размеров шин и #{tire_offers.count} предложений"
      }
      
    else
      # Модель не указана, показываем популярные модели бренда
      popular_models = get_popular_models(brand[:id])
      
      render json: {
        status: :model_required,
        message: "Укажите модель автомобиля для марки #{brand[:name]}",
        brand: brand,
        popular_models: popular_models
      }
    end
  end

  # Поиск товаров поставщиков для размеров шин
  def find_tire_offers(tire_sizes)
    offers = []
    
    tire_sizes.each do |size|
      products = SupplierTireProduct.where(
        width: size[:width],
        height: size[:height],
        diameter: size[:diameter]
      ).limit(3) # Ограничиваем для производительности
      
      products.each do |product|
        offers << {
          id: product.id,
          brand: product.original_brand,
          model: product.original_model,
          size: "#{product.width}/#{product.height}R#{product.diameter}",
          season: product.season,
          price: product.price_uah,
          tire_size_info: size
        }
      end
    end
    
    # Сортируем по популярности и цене
    offers.sort_by { |offer| [offer[:price] || Float::INFINITY] }.first(20)
  end

  # Получение популярных моделей бренда
  def get_popular_models(brand_id)
    CarModel.joins(:car_tire_configurations)
            .where(brand_id: brand_id)
            .group('car_models.id, car_models.name')
            .select('car_models.*, COUNT(car_tire_configurations.id) as configs_count')
            .order('configs_count DESC')
            .limit(10)
            .map do |model|
      {
        id: model.id,
        name: model.name,
        configs_count: model.try(:configs_count) || 0
      }
    end
  end

  # Получение предложений похожих брендов
  def get_brand_suggestions(query)
    # Простые предложения на основе популярности
    CarBrand.joins(:car_tire_configurations)
            .group('car_brands.id, car_brands.name')
            .select('car_brands.*, COUNT(car_tire_configurations.id) as configs_count')
            .order('configs_count DESC')
            .limit(5)
            .map { |brand| format_brand(brand) }
  end

  # Форматирование данных бренда
  def format_brand(brand)
    {
      id: brand.id,
      name: brand.name,
      configs_count: brand.try(:configs_count) || CarTireConfiguration.where(brand_id: brand.id).count,
      models_count: CarModel.where(brand_id: brand.id).count
    }
  end

  # Установка локали
  def set_locale
    I18n.locale = params[:locale] || :ru
  end
end