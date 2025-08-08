require 'nokogiri'
require 'digest'

class SupplierXmlProcessor
  attr_reader :supplier, :xml_content, :statistics, :errors
  
  def initialize(supplier, xml_content)
    @supplier = supplier
    @xml_content = xml_content
    @statistics = {
      total_items: 0,
      processed_items: 0,
      updated_items: 0,
      created_items: 0,
      skipped_items: 0,
      error_items: 0,
      processing_time_ms: 0
    }
    @errors = []
    @start_time = nil
  end
  
  def process
    Rails.logger.info "🔄 Начинаем обработку XML прайса для поставщика #{supplier.name} (ID: #{supplier.firm_id})"
    
    @start_time = Time.current
    
    begin
      # Валидация XML
      validate_xml_structure
      
      # Создание версии прайса
      version = create_price_version
      
      # Парсинг и обработка товаров
      process_items(version)
      
      # Обновление статистики
      finalize_processing(version)
      
      # Автоматическая нормализация новых товаров
      normalization_stats = run_auto_normalization
      
      # Обновление времени синхронизации поставщика
      supplier.update!(last_sync_at: Time.current)
      
      {
        success: true,
        version: version,
        statistics: @statistics,
        normalization: normalization_stats,
        message: "Обработано #{@statistics[:processed_items]} из #{@statistics[:total_items]} товаров. Нормализация: #{normalization_stats[:summary]}"
      }
      
    rescue StandardError => e
      Rails.logger.error "❌ Ошибка обработки XML: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      {
        success: false,
        error: e.message,
        statistics: @statistics
      }
    end
  end
  
  private
  
  def validate_xml_structure
    @doc = Nokogiri::XML(@xml_content)
    
    if @doc.errors.any?
      raise "Некорректный XML: #{@doc.errors.first.message}"
    end
    
    # Проверяем базовую структуру
    price_node = @doc.at_xpath('//price')
    raise "Отсутствует корневой элемент <price>" unless price_node
    
    firm_id_node = @doc.at_xpath('//firmId')
    raise "Отсутствует элемент <firmId>" unless firm_id_node
    
    # Проверяем соответствие firmId
    xml_firm_id = firm_id_node.text.strip
    unless xml_firm_id == supplier.firm_id
      raise "Несоответствие firmId: ожидается #{supplier.firm_id}, получен #{xml_firm_id}"
    end
    
    items_node = @doc.at_xpath('//items')
    raise "Отсутствует элемент <items>" unless items_node
    
    Rails.logger.info "✅ XML структура валидна"
  end
  
  def create_price_version
    file_checksum = Digest::SHA256.hexdigest(@xml_content)
    items_count = @doc.xpath('//item').count
    
    @statistics[:total_items] = items_count
    
    version = supplier.supplier_price_versions.create!(
      file_checksum: file_checksum,
      products_count: items_count
    )
    
    Rails.logger.info "📦 Создана версия прайса: #{version.version} (товаров: #{items_count})"
    version
  end
  
  def process_items(version)
    Rails.logger.info "🔄 Обрабатываем товары..."
    
    # Сначала обнуляем цены и убираем наличие у всех существующих товаров поставщика
    Rails.logger.info "💰 Обнуляем цены и убираем наличие у существующих товаров поставщика #{supplier.name}..."
    supplier.supplier_tire_products.update_all(
      price_uah: nil,
      in_stock: false,
      stock_status: 'out_of_stock',
      updated_at: Time.current
    )
    
    # Создаем хеш для быстрого поиска существующих товаров по external_id
    existing_products = supplier.supplier_tire_products.index_by(&:external_id)
    Rails.logger.info "📦 Найдено #{existing_products.size} существующих товаров для обновления"
    
    @doc.xpath('//item').each_with_index do |item_node, index|
      begin
        process_single_item(item_node, version, existing_products)
        @statistics[:processed_items] += 1
        
        # Логируем прогресс каждые 1000 товаров
        if (index + 1) % 1000 == 0
          Rails.logger.info "📊 Обработано #{index + 1} из #{@statistics[:total_items]} товаров"
        end
        
      rescue StandardError => e
        @statistics[:error_items] += 1
        error_msg = "Ошибка обработки товара #{index + 1}: #{e.message}"
        @errors << error_msg
        Rails.logger.warn "⚠️ #{error_msg}"
        
        # Прерываем обработку если слишком много ошибок
        if @statistics[:error_items] > @statistics[:total_items] * 0.5
          raise "Слишком много ошибок обработки (>50%), прерываем загрузку"
        end
      end
    end
  end
  
  def process_single_item(item_node, version, existing_products)
    # Извлекаем основные поля
    item_data = extract_item_data(item_node)
    
    # Валидируем обязательные поля
    validate_item_data(item_data)
    
    # Пропускаем товары не в наличии
    return if item_data[:stock_status].match?(/не\s*в\s*наявності|немає|відсутній/i)
    
    # Пропускаем товары с некорректными размерами
    return unless valid_tire_size?(item_data)
    
    # Обновляем существующий товар или создаем новый
    update_or_create_tire_product(item_data, item_node, existing_products)
  end
  
  def extract_item_data(item_node)
    # Извлекаем параметры шины из <param> элементов
    params = {}
    item_node.xpath('.//param').each do |param|
      name = param['name']&.strip
      value = param.text&.strip
      params[name] = value if name && value
    end
    
    {
      external_id: item_node.at_xpath('./id')&.text&.strip,
      vendor: item_node.at_xpath('./vendor')&.text&.strip,
      name: item_node.at_xpath('./name')&.text&.strip,
      description: item_node.at_xpath('./description')&.text&.strip,
      price_uah: item_node.at_xpath('./priceRUAH')&.text&.to_f,
      stock_status: item_node.at_xpath('./stock')&.text&.strip,
      image_url: item_node.at_xpath('./image')&.text&.strip,
      product_url: item_node.at_xpath('./url')&.text&.strip,
      
      # Параметры из <param> элементов
      tire_type: params['Тип'],
      width: params['Ширина профілю шини, мм']&.to_i,
      height: params['Висота профілю шини, %']&.to_i,
      diameter: params['Внутрішній діаметр покришки, дюйми'],
      load_index: params['Вантажопідйомність, кг'],
      speed_index: params['Швидкість максимальна, км/г'],
      country: params['Країна виготовлення'],
      year_week: params['Рік виготовлення']
    }
  end
  
  def validate_item_data(data)
    required_fields = [:external_id, :vendor, :name, :tire_type, :width, :height, :diameter]
    
    required_fields.each do |field|
      if data[field].blank?
        raise "Отсутствует обязательное поле: #{field}"
      end
    end
  end
  
  def valid_tire_size?(data)
    return false unless data[:width] && data[:height] && data[:diameter]
    
    # Проверяем разумные диапазоны размеров
    width_valid = data[:width].between?(125, 355)  # ширина в мм
    height_valid = data[:height].between?(25, 95)  # высота в %
    diameter_valid = data[:diameter].to_s.match?(/^\d{2}C?$/) # диаметр в дюймах
    
    width_valid && height_valid && diameter_valid
  end
  
  def update_or_create_tire_product(data, item_node, existing_products)
    # Извлекаем модель из названия (простая эвристика)
    model = extract_model_from_name(data[:name], data[:vendor])
    
    # Подготавливаем атрибуты для обновления/создания
    attributes = {
      brand: data[:vendor],
      model: model,
      name: data[:name],
      width: data[:width],
      height: data[:height],
      diameter: data[:diameter],
      load_index: data[:load_index],
      speed_index: data[:speed_index],
      season: normalize_season(data[:tire_type]),
      price_uah: data[:price_uah],
      stock_status: data[:stock_status],
      in_stock: true, # товар в новом прайсе = в наличии
      description: data[:description],
      image_url: data[:image_url],
      product_url: data[:product_url],
      country: data[:country],
      year_week: data[:year_week],
      raw_data: item_node.to_h, # сохраняем исходные данные
      updated_at: Time.current
    }
    
    # Проверяем, существует ли товар с таким external_id
    existing_product = existing_products[data[:external_id]]
    
    if existing_product
      # Обновляем существующий товар
      existing_product.update!(attributes)
      @statistics[:updated_items] += 1
      Rails.logger.debug "🔄 Обновлен товар: #{data[:external_id]} - #{data[:name]}"
    else
      # Создаем новый товар
      supplier.supplier_tire_products.create!(
        attributes.merge(external_id: data[:external_id])
      )
      @statistics[:created_items] += 1
      Rails.logger.debug "➕ Создан новый товар: #{data[:external_id]} - #{data[:name]}"
    end
  end
  
  def extract_model_from_name(name, brand)
    return 'Unknown' if name.blank? || brand.blank?
    
    # Убираем бренд из начала названия
    model_part = name.gsub(/^#{Regexp.escape(brand)}\s*/i, '')
    
    # Убираем размеры в скобках
    model_part = model_part.gsub(/\s*\([^)]+\)\s*$/, '')
    
    # Берем первые слова до размера или технических характеристик
    model_part.split(/\s+/).first(3).join(' ').strip
  end
  
  def normalize_season(tire_type)
    return 'unknown' if tire_type.blank?
    
    case tire_type.downcase
    when /зимов/
      'winter'
    when /літн/
      'summer'
    when /всесезон/
      'all_season'
    else
      'unknown'
    end
  end
  
  def finalize_processing(version)
    processing_time = ((Time.current - @start_time) * 1000).to_i
    @statistics[:processing_time_ms] = processing_time
    
    version.update!(
      processed_count: @statistics[:processed_items],
      errors_count: @statistics[:error_items],
      processing_time_ms: processing_time
    )
    
    Rails.logger.info "✅ Обработка завершена за #{processing_time}мс"
    Rails.logger.info "📊 Статистика: обработано #{@statistics[:processed_items]} (обновлено #{@statistics[:updated_items]}, создано #{@statistics[:created_items]}), ошибок #{@statistics[:error_items]}"
  end

  # Автоматическая нормализация товаров после загрузки прайса
  def run_auto_normalization
    Rails.logger.info "🔄 Запуск автоматической нормализации товаров поставщика #{supplier.name}..."
    normalization_start = Time.current
    
    begin
      # Получаем товары поставщика для нормализации
      products_to_normalize = supplier.supplier_tire_products
                                     .where(tire_brand_id: nil)
                                     .or(supplier.supplier_tire_products.where(country_id: nil))
                                     .or(supplier.supplier_tire_products.where(optimality_score: nil))
      
      total_for_normalization = products_to_normalize.count
      
      if total_for_normalization.zero?
        Rails.logger.info "✅ Все товары поставщика уже нормализованы"
        return {
          total_products: supplier.supplier_tire_products.count,
          processed: 0,
          normalized_brands: 0,
          normalized_countries: 0,
          normalized_models: 0,
          processing_time_ms: 0,
          summary: "все товары уже нормализованы"
        }
      end
      
      Rails.logger.info "📦 Найдено #{total_for_normalization} товаров для нормализации"
      
      # Инициализируем сервис нормализации
      normalization_service = TireNormalizationService.new(batch_size: 100)
      
      # Статистика нормализации
      norm_stats = {
        processed: 0,
        normalized_brands: 0,
        normalized_countries: 0,
        normalized_models: 0,
        failed: 0
      }
      
      # Обрабатываем товары пакетами
      products_to_normalize.find_in_batches(batch_size: 100) do |batch|
        batch.each do |product|
          begin
            # Сохраняем исходное состояние для подсчета изменений
            had_brand = product.tire_brand_id.present?
            had_country = product.country_id.present?
            had_model = product.tire_model_id.present?
            
            # Запускаем нормализацию продукта
            normalization_service.normalize_product(product)
            
            # Подсчитываем что было нормализовано
            norm_stats[:normalized_brands] += 1 if !had_brand && product.reload.tire_brand_id.present?
            norm_stats[:normalized_countries] += 1 if !had_country && product.country_id.present?
            norm_stats[:normalized_models] += 1 if !had_model && product.tire_model_id.present?
            
            norm_stats[:processed] += 1
            
            # Логируем прогресс каждые 50 товаров
            if norm_stats[:processed] % 50 == 0
              Rails.logger.info "📈 Нормализовано: #{norm_stats[:processed]}/#{total_for_normalization}"
            end
            
          rescue StandardError => e
            norm_stats[:failed] += 1
            Rails.logger.warn "⚠️ Ошибка нормализации товара ID=#{product.id}: #{e.message}"
          end
        end
      end
      
      processing_time = ((Time.current - normalization_start) * 1000).round(2)
      
      # Формируем краткое резюме
      summary_parts = []
      summary_parts << "#{norm_stats[:normalized_brands]} брендов" if norm_stats[:normalized_brands] > 0
      summary_parts << "#{norm_stats[:normalized_countries]} стран" if norm_stats[:normalized_countries] > 0  
      summary_parts << "#{norm_stats[:normalized_models]} моделей" if norm_stats[:normalized_models] > 0
      
      summary = if summary_parts.any?
                  "нормализовано #{summary_parts.join(', ')}"
                else
                  "новых связей не найдено"
                end
      
      # Итоговая статистика
      final_stats = {
        total_products: supplier.supplier_tire_products.count,
        processed: norm_stats[:processed],
        normalized_brands: norm_stats[:normalized_brands],
        normalized_countries: norm_stats[:normalized_countries], 
        normalized_models: norm_stats[:normalized_models],
        failed: norm_stats[:failed],
        processing_time_ms: processing_time,
        summary: summary
      }
      
      Rails.logger.info "✅ Нормализация завершена за #{processing_time}мс"
      Rails.logger.info "📊 Результат: #{summary} (ошибок: #{norm_stats[:failed]})"
      
      return final_stats
      
    rescue StandardError => e
      processing_time = ((Time.current - normalization_start) * 1000).round(2)
      Rails.logger.error "❌ Ошибка автоматической нормализации: #{e.message}"
      
      return {
        total_products: supplier.supplier_tire_products.count,
        processed: 0,
        normalized_brands: 0,
        normalized_countries: 0,
        normalized_models: 0,
        failed: 1,
        processing_time_ms: processing_time,
        summary: "ошибка нормализации: #{e.message}",
        error: e.message
      }
    end
  end
end