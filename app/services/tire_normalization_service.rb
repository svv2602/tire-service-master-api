# frozen_string_literal: true

# Сервис для нормализации данных шин
# Связывает продукты поставщиков со справочными данными
class TireNormalizationService
  # Логирование процесса нормализации
  include ActionView::Helpers::TextHelper

  def initialize(batch_size: 100)
    @batch_size = batch_size
    @stats = {
      processed: 0,
      normalized_brands: 0,
      normalized_models: 0,
      normalized_countries: 0,
      failed: 0,
      skipped: 0
    }
  end

  # Основной метод нормализации всех товаров
  def normalize_all_products!
    puts "🔄 Начало нормализации товаров поставщиков..."
    start_time = Time.current
    
    total_products = SupplierTireProduct.count
    puts "📊 Всего товаров для обработки: #{total_products}"
    
    # Обрабатываем пакетами для экономии памяти
    SupplierTireProduct.find_in_batches(batch_size: @batch_size) do |batch|
      normalize_batch(batch)
      
      progress = (@stats[:processed].to_f / total_products * 100).round(2)
      puts "  📈 Обработано: #{@stats[:processed]}/#{total_products} (#{progress}%)"
    end
    
    duration = Time.current - start_time
    print_final_stats(duration)
    
    @stats
  end

  # Нормализация конкретного товара
  def normalize_product(product)
    Rails.logger.info "Нормализация товара ID=#{product.id}: #{product.original_brand} #{product.original_model}"
    
    changes_made = false
    
    # Нормализация бренда
    if normalize_brand_for_product(product)
      changes_made = true
      @stats[:normalized_brands] += 1
    end
    
    # Нормализация модели (только если бренд определен)
    if product.tire_brand_id && normalize_model_for_product(product)
      changes_made = true
      @stats[:normalized_models] += 1
    end
    
    # Нормализация страны
    if normalize_country_for_product(product)
      changes_made = true
      @stats[:normalized_countries] += 1
    end
    
    # Расчет рейтинга оптимальности
    if update_optimality_score(product)
      changes_made = true
    end
    
    # Сохраняем только если были изменения
    if changes_made
      product.save!
      Rails.logger.debug "Товар ID=#{product.id} сохранен с обновлениями"
    else
      @stats[:skipped] += 1
    end
    
    @stats[:processed] += 1
    
  rescue StandardError => e
    @stats[:failed] += 1
    Rails.logger.error "Ошибка нормализации товара ID=#{product.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  # Нормализация пакета товаров
  def normalize_batch(batch)
    batch.each { |product| normalize_product(product) }
  end

  # Нormalization of brand for product with regex fallback
  def normalize_brand_for_product(product)
    return false if product.tire_brand_id.present?

    # Primary: DB lookup by normalized name and aliases
    tire_brand = find_tire_brand(product.original_brand)

    # Fallback: regex-based normalization when DB lookup fails
    tire_brand ||= regex_find_tire_brand(product.original_brand)

    if tire_brand
      product.tire_brand_id = tire_brand.id
      Rails.logger.debug "Найден бренд: #{product.original_brand} -> #{tire_brand.name}"
      return true
    end

    Rails.logger.warn "Бренд не найден: #{product.original_brand}"
    false
  end

  # Normalization of model for product with regex fallback
  def normalize_model_for_product(product)
    return false if product.tire_model_id.present?
    return false unless product.tire_brand_id

    # Primary: DB lookup by normalized name and aliases
    tire_model = find_tire_model(product.original_model, product.tire_brand_id)

    # Fallback: regex-based normalization when DB lookup fails
    tire_model ||= regex_find_tire_model(product.original_model, product.tire_brand_id)

    if tire_model
      product.tire_model_id = tire_model.id
      Rails.logger.debug "Найдена модель: #{product.original_model} -> #{tire_model.name}"
      return true
    end

    Rails.logger.debug "Модель не найдена: #{product.original_model} для бренда ID=#{product.tire_brand_id}"
    false
  end

  # Нормализация страны для товара
  def normalize_country_for_product(product)
    return false if product.country_id.present?
    return false if product.original_country.blank?
    
    # Ищем страну по названию и алиасам
    country = find_country(product.original_country)
    
    if country
      product.country_id = country.id
      Rails.logger.debug "Найдена страна: #{product.original_country} -> #{country.name}"
      return true
    end
    
    Rails.logger.warn "Страна не найдена: #{product.original_country}"
    false
  end

  # Поиск бренда по названию и алиасам
  def find_tire_brand(brand_name)
    return nil if brand_name.blank?
    
    normalized_name = TireBrand.send(:normalize_string, brand_name)
    
    # Сначала ищем по нормализованному названию
    tire_brand = TireBrand.active.find_by(normalized_name: normalized_name)
    return tire_brand if tire_brand
    
    # Затем ищем по алиасам
    TireBrand.active.where("? = ANY(aliases)", brand_name).first ||
    TireBrand.active.where("? = ANY(aliases)", normalized_name).first
  end

  # Поиск модели по названию и алиасам в рамках бренда
  def find_tire_model(model_name, tire_brand_id)
    return nil if model_name.blank?
    
    normalized_name = TireModel.send(:normalize_string, model_name)
    
    # Сначала ищем по нормализованному названию
    tire_model = TireModel.active
                         .where(tire_brand_id: tire_brand_id)
                         .find_by(normalized_name: normalized_name)
    return tire_model if tire_model
    
    # Затем ищем по алиасам
    TireModel.active
             .where(tire_brand_id: tire_brand_id)
             .where("? = ANY(aliases)", model_name)
             .first ||
    TireModel.active
             .where(tire_brand_id: tire_brand_id)
             .where("? = ANY(aliases)", normalized_name)
             .first
  end

  # Поиск страны по названию и алиасам
  def find_country(country_name)
    return nil if country_name.blank?
    
    normalized_name = Country.send(:normalize_string, country_name)
    
    # Сначала ищем по нормализованному названию
    country = Country.active.find_by(normalized_name: normalized_name)
    return country if country
    
    # Затем ищем по алиасам
    Country.active.where("? = ANY(aliases)", country_name).first ||
    Country.active.where("? = ANY(aliases)", normalized_name).first
  end

  # Расчет рейтинга оптимальности товара
  def update_optimality_score(product)
    return false if product.optimality_score.present?
    
    score = calculate_optimality_score(product)
    product.optimality_score = score
    
    Rails.logger.debug "Рассчитан рейтинг оптимальности: #{score} для товара ID=#{product.id}"
    true
  end

  # Алгоритм расчета рейтинга оптимальности
  def calculate_optimality_score(product)
    score = 0.0
    
    # Рейтинг бренда (40% веса)
    if product.tire_brand&.rating_score
      score += product.tire_brand.rating_score * 4.0
    else
      score += 20.0 # Средний балл для неизвестных брендов
    end
    
    # Рейтинг страны производства (30% веса)
    if product.country&.rating_score
      score += product.country.rating_score * 3.0
    else
      score += 15.0 # Средний балл для неизвестных стран
    end
    
    # Премиум сегмент (+10 баллов)
    score += 10.0 if product.tire_brand&.is_premium
    
    # Год производства (10% веса)
    if product.production_year && product.production_year >= 2020
      years_old = Date.current.year - product.production_year
      score += [10.0 - years_old * 2, 0].max
    else
      score += 5.0 # Средний балл для неизвестного года
    end
    
    # Наличие на складе (+5 баллов)
    score += 5.0 if product.in_stock
    
    # Нормализация к шкале 1-100
    [[score, 100.0].min, 1.0].max.round(2)
  end

  # Финальная статистика
  def print_final_stats(duration)
    puts "\n✅ НОРМАЛИЗАЦИЯ ЗАВЕРШЕНА!"
    puts "⏱️ Время выполнения: #{duration.round(2)} сек"
    puts "\n📊 СТАТИСТИКА:"
    puts "  📦 Обработано товаров: #{@stats[:processed]}"
    puts "  🏷️ Нормализовано брендов: #{@stats[:normalized_brands]}"
    puts "  🚗 Нормализовано моделей: #{@stats[:normalized_models]}"
    puts "  🌍 Нормализовано стран: #{@stats[:normalized_countries]}"
    puts "  ⏭️ Пропущено (уже нормализованы): #{@stats[:skipped]}"
    puts "  ❌ Ошибок: #{@stats[:failed]}"
    
    # Процентное покрытие нормализации
    total_with_brands = SupplierTireProduct.where.not(tire_brand_id: nil).count
    total_with_models = SupplierTireProduct.where.not(tire_model_id: nil).count
    total_with_countries = SupplierTireProduct.where.not(country_id: nil).count
    total_products = SupplierTireProduct.count
    
    puts "\n📈 ПОКРЫТИЕ НОРМАЛИЗАЦИИ:"
    puts "  🏷️ Бренды: #{total_with_brands}/#{total_products} (#{percentage(total_with_brands, total_products)}%)"
    puts "  🚗 Модели: #{total_with_models}/#{total_products} (#{percentage(total_with_models, total_products)}%)"
    puts "  🌍 Страны: #{total_with_countries}/#{total_products} (#{percentage(total_with_countries, total_products)}%)"
  end

  # === Regex-based fallback normalization ===

  # Regex fallback for brand normalization
  # Cleans and standardizes brand name, then searches DB with fuzzy match
  # @param brand_name [String] Original brand name from supplier
  # @return [TireBrand, nil] Matched brand or nil
  def regex_find_tire_brand(brand_name)
    return nil if brand_name.blank?

    # Step 1: Clean the brand name (remove extra whitespace, special chars)
    cleaned = brand_name.to_s
                        .gsub(/[^\p{L}\p{N}\s\-]/u, '') # Keep letters, numbers, spaces, hyphens
                        .gsub(/\s+/, ' ')
                        .strip

    return nil if cleaned.blank?

    # Step 2: Try case-insensitive ILIKE search on name field
    tire_brand = TireBrand.active.where('name ILIKE ?', cleaned).first
    return tire_brand if tire_brand

    # Step 3: Try with common transliteration patterns
    transliterated = regex_transliterate_brand(cleaned)
    if transliterated != cleaned.downcase
      tire_brand = TireBrand.active.where('LOWER(name) = ?', transliterated).first
      return tire_brand if tire_brand
    end

    # Step 4: Fuzzy partial match (brand starts with or contains)
    tire_brand = TireBrand.active.where('name ILIKE ?', "#{cleaned}%").first
    return tire_brand if tire_brand

    nil
  end

  # Regex fallback for model normalization
  # Cleans model name and searches with fuzzy matching within brand
  # @param model_name [String] Original model name
  # @param tire_brand_id [Integer] Brand ID to scope search
  # @return [TireModel, nil] Matched model or nil
  def regex_find_tire_model(model_name, tire_brand_id)
    return nil if model_name.blank?

    # Clean the model name
    cleaned = model_name.to_s
                        .gsub(/[^\p{L}\p{N}\s\-\.\/]/u, '')
                        .gsub(/\s+/, ' ')
                        .strip

    return nil if cleaned.blank?

    # Try case-insensitive match within brand
    TireModel.active
             .where(tire_brand_id: tire_brand_id)
             .where('name ILIKE ?', cleaned)
             .first ||
      TireModel.active
               .where(tire_brand_id: tire_brand_id)
               .where('name ILIKE ?', "#{cleaned}%")
               .first
  end

  # Simple transliteration for common tire brand names (Cyrillic -> Latin)
  BRAND_TRANSLITERATIONS = {
    'мишлен' => 'michelin', 'мишелин' => 'michelin',
    'бриджстоун' => 'bridgestone', 'бриджстон' => 'bridgestone',
    'континенталь' => 'continental', 'конти' => 'continental',
    'пирелли' => 'pirelli', 'пирели' => 'pirelli',
    'гудьир' => 'goodyear', 'гудиер' => 'goodyear',
    'данлоп' => 'dunlop',
    'йокохама' => 'yokohama', 'иокохама' => 'yokohama',
    'ханкук' => 'hankook', 'ханкок' => 'hankook',
    'кумхо' => 'kumho',
    'нокиан' => 'nokian',
    'купер' => 'cooper',
    'тойо' => 'toyo',
    'фалькен' => 'falken',
    'кордиант' => 'cordiant',
    'виатти' => 'viatti',
    'белшина' => 'belshina',
    'росава' => 'rosava',
    'кама' => 'kama'
  }.freeze

  def regex_transliterate_brand(brand_name)
    normalized = brand_name.to_s.strip.downcase
    BRAND_TRANSLITERATIONS[normalized] || normalized
  end

  # Вычисление процента
  def percentage(part, total)
    return 0 if total.zero?
    (part.to_f / total * 100).round(1)
  end
end