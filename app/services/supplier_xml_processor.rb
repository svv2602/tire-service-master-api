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
      
      # Обновление времени синхронизации поставщика
      supplier.update!(last_sync_at: Time.current)
      
      {
        success: true,
        version: version,
        statistics: @statistics,
        message: "Обработано #{@statistics[:processed_items]} из #{@statistics[:total_items]} товаров"
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
end