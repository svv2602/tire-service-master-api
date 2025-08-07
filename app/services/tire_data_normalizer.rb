# frozen_string_literal: true

# Сервис для нормализации и сопоставления данных шин с справочниками
class TireDataNormalizer
  # Конфигурация для fuzzy matching
  SIMILARITY_THRESHOLD = 0.8
  MAX_LEVENSHTEIN_DISTANCE = 3

  class << self
    # Основной метод нормализации товара поставщика
    def normalize_product(product)
      Rails.logger.info "🔧 Нормализация товара: #{product.original_brand} #{product.original_model}"
      
      # Нормализуем бренд
      tire_brand = normalize_brand(product.original_brand)
      
      # Нормализуем модель
      tire_model = normalize_model(product.original_model, tire_brand&.id, product.season)
      
      # Нормализуем страну
      country = normalize_country(product.original_country)
      
      # Извлекаем год производства
      production_year = extract_production_year(product.year_week)
      
      # Обновляем товар
      product.update!(
        tire_brand: tire_brand,
        tire_model: tire_model,
        country: country,
        production_year: production_year
      )
      
      Rails.logger.info "✅ Товар нормализован: #{tire_brand&.name} #{tire_model&.name}"
      product
    end

    # Пакетная нормализация всех товаров
    def normalize_all_products(batch_size: 1000)
      Rails.logger.info "🚀 Начинается пакетная нормализация товаров"
      
      total_count = SupplierTireProduct.where(tire_brand_id: nil).count
      processed = 0
      
      SupplierTireProduct.where(tire_brand_id: nil).find_in_batches(batch_size: batch_size) do |batch|
        batch.each do |product|
          begin
            normalize_product(product)
            processed += 1
            
            # Логируем прогресс каждые 100 товаров
            if processed % 100 == 0
              Rails.logger.info "📊 Обработано #{processed}/#{total_count} товаров"
            end
          rescue => e
            Rails.logger.error "❌ Ошибка нормализации товара #{product.id}: #{e.message}"
            next
          end
        end
      end
      
      Rails.logger.info "🎉 Пакетная нормализация завершена: #{processed} товаров"
    end

    private

    # Нормализация бренда
    def normalize_brand(brand_name)
      return nil if brand_name.blank?
      
      # Поиск существующего бренда
      brand = TireBrand.find_by_name_or_alias(brand_name)
      return brand if brand
      
      # Fuzzy поиск среди существующих брендов
      brand = find_similar_brand(brand_name)
      return brand if brand
      
      # Создаем новый бренд
      TireBrand.find_or_create_by_name(brand_name)
    rescue => e
      Rails.logger.error "❌ Ошибка нормализации бренда '#{brand_name}': #{e.message}"
      nil
    end

    # Нормализация модели
    def normalize_model(model_name, brand_id, season_type = nil)
      return nil if model_name.blank? || brand_id.blank?
      
      # Поиск существующей модели
      model = TireModel.find_by_name_or_alias(model_name, brand_id)
      return model if model
      
      # Fuzzy поиск среди моделей бренда
      model = find_similar_model(model_name, brand_id)
      return model if model
      
      # Создаем новую модель
      TireModel.find_or_create_by_name(model_name, brand_id, season_type)
    rescue => e
      Rails.logger.error "❌ Ошибка нормализации модели '#{model_name}': #{e.message}"
      nil
    end

    # Нормализация страны
    def normalize_country(country_name)
      return nil if country_name.blank?
      
      # Поиск существующей страны
      country = Country.find_by_name_or_alias(country_name)
      return country if country
      
      # Создаем новую страну
      Country.find_or_create_by_name(country_name)
    rescue => e
      Rails.logger.error "❌ Ошибка нормализации страны '#{country_name}': #{e.message}"
      nil
    end

    # Извлечение года производства из year_week
    def extract_production_year(year_week)
      return nil if year_week.blank?
      
      # Форматы: "2024-30", "2024W30", "2430", "24/30"
      year_match = year_week.to_s.match(/(?:20)?(\d{2})/)
      return nil unless year_match
      
      year = year_match[1].to_i
      
      # Преобразуем двузначный год в четырехзначный
      if year >= 0 && year <= 30
        year += 2000
      elsif year >= 90 && year <= 99
        year += 1900
      else
        year += 2000
      end
      
      # Валидация года (разумные пределы)
      return year if year >= 2010 && year <= Time.current.year + 1
      
      nil
    rescue => e
      Rails.logger.error "❌ Ошибка извлечения года из '#{year_week}': #{e.message}"
      nil
    end

    # Fuzzy поиск похожего бренда
    def find_similar_brand(brand_name)
      normalized_input = normalize_string(brand_name)
      
      TireBrand.active.find do |brand|
        # Проверяем похожесть с основным названием
        return brand if strings_similar?(normalized_input, brand.normalized_name)
        
        # Проверяем похожесть с алиасами
        brand.aliases.any? { |alias_name| strings_similar?(normalized_input, alias_name) }
      end
    end

    # Fuzzy поиск похожей модели
    def find_similar_model(model_name, brand_id)
      normalized_input = normalize_string(model_name)
      
      TireModel.by_brand(brand_id).active.find do |model|
        # Проверяем похожесть с основным названием
        return model if strings_similar?(normalized_input, model.normalized_name)
        
        # Проверяем похожесть с алиасами
        model.aliases.any? { |alias_name| strings_similar?(normalized_input, alias_name) }
      end
    end

    # Проверка похожести строк
    def strings_similar?(str1, str2)
      return false if str1.blank? || str2.blank?
      
      # Точное совпадение
      return true if str1 == str2
      
      # Проверка включения одной строки в другую
      return true if str1.include?(str2) || str2.include?(str1)
      
      # Levenshtein distance для коротких строк
      if str1.length <= 20 && str2.length <= 20
        distance = levenshtein_distance(str1, str2)
        max_length = [str1.length, str2.length].max
        return distance <= MAX_LEVENSHTEIN_DISTANCE && (1.0 - distance.to_f / max_length) >= SIMILARITY_THRESHOLD
      end
      
      false
    end

    # Вычисление расстояния Левенштейна
    def levenshtein_distance(str1, str2)
      matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1, 0) }
      
      (0..str1.length).each { |i| matrix[i][0] = i }
      (0..str2.length).each { |j| matrix[0][j] = j }
      
      (1..str1.length).each do |i|
        (1..str2.length).each do |j|
          cost = str1[i - 1] == str2[j - 1] ? 0 : 1
          matrix[i][j] = [
            matrix[i - 1][j] + 1,     # deletion
            matrix[i][j - 1] + 1,     # insertion
            matrix[i - 1][j - 1] + cost # substitution
          ].min
        end
      end
      
      matrix[str1.length][str2.length]
    end

    # Нормализация строки
    def normalize_string(str)
      str.to_s.strip.downcase.gsub(/[^\p{L}\p{N}\s]/, '').squeeze(' ')
    end
  end
end