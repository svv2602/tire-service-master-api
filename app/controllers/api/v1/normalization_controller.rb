# frozen_string_literal: true

class Api::V1::NormalizationController < ApplicationController
  before_action :ensure_admin!

  # GET /api/v1/normalization/stats
  # Статистика нормализации
  def stats
    total = SupplierTireProduct.count
    with_brand = SupplierTireProduct.where.not(tire_brand_id: nil).count
    with_model = SupplierTireProduct.where.not(tire_model_id: nil).count
    with_country = SupplierTireProduct.where.not(country_id: nil).count
    with_score = SupplierTireProduct.where.not(optimality_score: nil).count

    # Статистика справочников
    countries_count = Country.count
    brands_count = TireBrand.count
    models_count = TireModel.count

    render json: {
      total_products: total,
      brand_coverage: calculate_percentage(with_brand, total),
      model_coverage: calculate_percentage(with_model, total),
      country_coverage: calculate_percentage(with_country, total),
      quality_score_coverage: calculate_percentage(with_score, total),
      reference_data: {
        countries_count: countries_count,
        brands_count: brands_count,
        models_count: models_count
      },
      last_update: Time.current.iso8601
    }
  end

  # GET /api/v1/normalization/unprocessed
  # Ненормализованные товары с пагинацией и фильтрацией
  def unprocessed
    # Параметры пагинации
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 20, 100].min
    
    # Параметры фильтрации
    missing_type = params[:missing_type] # 'brand', 'country', 'model', 'score'
    supplier_id = params[:supplier_id]
    search_term = params[:search]

    # Базовый запрос - товары без нормализации
    query = SupplierTireProduct.includes(:supplier, :tire_brand, :tire_model, :country)

    # Фильтр по типу отсутствующих данных
    case missing_type
    when 'brand'
      query = query.where(tire_brand_id: nil)
    when 'country'
      query = query.where(country_id: nil)
    when 'model'
      query = query.where(tire_model_id: nil)
    when 'score'
      query = query.where(optimality_score: nil)
    else
      # По умолчанию - товары без бренда (основной показатель нормализации)
      query = query.where(tire_brand_id: nil)
    end

    # Фильтр по поставщику
    if supplier_id.present?
      query = query.where(supplier_id: supplier_id)
    end

    # Поиск по названию, бренду, модели или стране
    # Проверяем не только present?, но и наличие параметра вообще
    if search_term.present? || (params.key?(:search) && search_term == '')
      # Особая обработка для пустых строк  
      if search_term.blank? || search_term.strip.empty?
        # Для пустого поиска ищем товары с пустыми original_* полями
        case missing_type
        when 'country'
          query = query.where(original_country: ['', nil])
        when 'brand'  
          query = query.where(original_brand: ['', nil])
        when 'model'
          query = query.where(original_model: ['', nil])
        end
      else
        search_pattern = "%#{search_term.downcase}%"
        query = query.where(
          "LOWER(name) LIKE ? OR LOWER(original_brand) LIKE ? OR LOWER(original_model) LIKE ? OR LOWER(original_country) LIKE ?",
          search_pattern, search_pattern, search_pattern, search_pattern
        )
      end
    end

    # Пагинация
    total_count = query.count
    offset = (page - 1) * per_page
    products = query.offset(offset).limit(per_page).order(:id)

    # Сериализация данных
    serialized_products = products.map do |product|
      {
        id: product.id,
        external_id: product.external_id,
        name: product.name,
        original_brand: product.original_brand,
        original_model: product.original_model,
        original_country: product.original_country,
        size_designation: product.size_designation,
        season: product.season,
        price_uah: product.price_uah,
        supplier: {
          id: product.supplier.id,
          name: product.supplier.name
        },
        normalization_status: {
          has_brand: product.tire_brand_id.present?,
          has_model: product.tire_model_id.present?,
          has_country: product.country_id.present?,
          has_score: product.optimality_score.present?
        },
        missing_fields: get_missing_fields(product)
      }
    end

    render json: {
      data: serialized_products,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil,
        missing_type: missing_type || 'brand'
      }
    }
  end

  # POST /api/v1/normalization/run
  # Запуск нормализации
  def run_normalization
    # Параметры для нормализации
    supplier_id = params[:supplier_id]
    product_ids = params[:product_ids]
    batch_size = params[:batch_size]&.to_i || 100

    begin
      service = TireNormalizationService.new(batch_size: batch_size)
      
      # Определяем продукты для нормализации
      if product_ids.present?
        # Нормализация конкретных товаров
        products = SupplierTireProduct.where(id: product_ids)
        result = service.normalize_products(products)
      elsif supplier_id.present?
        # Нормализация товаров конкретного поставщика
        products = SupplierTireProduct.where(supplier_id: supplier_id, tire_brand_id: nil)
        result = service.normalize_products(products)
      else
        # Полная нормализация всех ненормализованных товаров
        result = service.normalize_all_missing
      end

      render json: {
        success: true,
        message: "Нормализация выполнена успешно",
        statistics: result
      }
    rescue StandardError => e
      Rails.logger.error "Ошибка нормализации: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: {
        success: false,
        message: "Ошибка при выполнении нормализации: #{e.message}",
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/normalization/top_unprocessed
  # Топ необработанных брендов/стран/моделей
  def top_unprocessed
    type = params[:type] || 'brands' # 'brands', 'countries', 'models'
    limit = [params[:limit]&.to_i || 10, 50].min

    case type
    when 'brands'
      # Группируем по оригинальному бренду и получаем поставщиков
      brand_data = SupplierTireProduct
        .where(tire_brand_id: nil)
        .joins(:supplier)
        .group(:original_brand, :supplier_id)
        .count
        
      results = build_detailed_results(brand_data, limit, 'brand')
    when 'countries'
      # Группируем по оригинальной стране и получаем поставщиков
      country_data = SupplierTireProduct
        .where(country_id: nil)
        .joins(:supplier)
        .group(:original_country, :supplier_id)
        .count
        
      results = build_detailed_results(country_data, limit, 'country')
    when 'models'
      # Группируем по оригинальной модели и получаем поставщиков  
      model_data = SupplierTireProduct
        .where(tire_model_id: nil)
        .joins(:supplier)
        .group(:original_model, :supplier_id)
        .count
        
      results = build_detailed_results(model_data, limit, 'model')
    else
      results = []
    end

    render json: {
      type: type,
      data: results,
      total_missing: results.sum { |item| item[:count] }
    }
  end

  private

  def build_detailed_results(grouped_data, limit, type)
    # Группируем по названию и агрегируем поставщиков
    aggregated = {}
    
    grouped_data.each do |(name, supplier_id), count|
      aggregated[name] ||= { total_count: 0, suppliers: {} }
      aggregated[name][:total_count] += count
      aggregated[name][:suppliers][supplier_id] ||= 0
      aggregated[name][:suppliers][supplier_id] += count
    end
    
    # Преобразуем в итоговый формат
    results = aggregated.map do |name, data|
      # Получаем топ-3 поставщика для каждого проблемного названия
      top_suppliers = data[:suppliers]
        .map { |supplier_id, count| 
          supplier = Supplier.find(supplier_id)
          { name: supplier.name, count: count, id: supplier_id }
        }
        .sort_by { |s| -s[:count] }
        .first(5) # Берем топ-5 поставщиков
      
      {
        name: name,
        count: data[:total_count],
        type: type,
        suppliers: top_suppliers
      }
    end
    
    # Сортируем по общему количеству и берем топ
    results.sort_by { |item| -item[:count] }.first(limit)
  end

  def calculate_percentage(part, total)
    return 0.0 if total.zero?
    ((part.to_f / total) * 100).round(1)
  end

  def get_missing_fields(product)
    missing = []
    missing << 'brand' if product.tire_brand_id.blank?
    missing << 'model' if product.tire_model_id.blank?
    missing << 'country' if product.country_id.blank?
    missing << 'score' if product.optimality_score.blank?
    missing
  end
end