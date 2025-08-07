# frozen_string_literal: true

# Сервис для расчета рейтинга оптимальности шин по формулам пользователя
class TireOptimalityCalculator
  # Базовые веса параметров (W)
  DEFAULT_WEIGHTS = {
    brand: 0.2,          # Бренд
    country: 0.1,        # Страна производства  
    speed_index: 0.1,    # Индекс скорости
    load_index: 0.1,     # Индекс нагрузки
    production_year: 0.1, # Год производства
    model_rating: 0.2,   # Рейтинг модели
    price: 0.2           # Цена
  }.freeze

  # Коэффициенты приоритетов (Wk)
  PRIORITY_COEFFICIENTS = {
    'price_quality' => {
      brand: 2,
      country: 1,
      speed_index: 1,
      load_index: 1,
      production_year: 1,
      model_rating: 1,
      price: 2
    },
    'prestige' => {
      brand: 3,
      country: 2,
      speed_index: 1,
      load_index: 1,
      production_year: 2,
      model_rating: 3,
      price: 1
    },
    'functionality' => {
      brand: 1,
      country: 3,
      speed_index: 2,
      load_index: 2,
      production_year: 3,
      model_rating: 2,
      price: 1
    }
  }.freeze

  class << self
    # Основной метод расчета рейтинга оптимальности
    def calculate_optimality(product, options = {})
      priority_type = options[:priority_type] || 'balanced'
      max_price = options[:max_price]
      
      # Получаем коэффициенты приоритета
      coefficients = get_priority_coefficients(priority_type)
      
      # Рассчитываем оценки по каждому параметру
      scores = {
        brand: calculate_brand_score(product),
        country: calculate_country_score(product),
        speed_index: calculate_speed_index_score(product),
        load_index: calculate_load_index_score(product),
        production_year: calculate_production_year_score(product),
        model_rating: calculate_model_rating_score(product),
        price: calculate_price_score(product, max_price)
      }
      
      # Применяем формулу расчета
      total_score = 0
      DEFAULT_WEIGHTS.each do |param, weight|
        score = scores[param] || 0
        coefficient = coefficients[param] || 1
        weighted_score = weight * coefficient * score
        total_score += weighted_score
        
        Rails.logger.debug "🧮 #{param}: score=#{score}, weight=#{weight}, coeff=#{coefficient}, result=#{weighted_score}"
      end
      
      # Нормализуем результат от 0 до 10
      normalized_score = [total_score, 10.0].min
      
      Rails.logger.info "🎯 Рейтинг оптимальности для товара #{product.id}: #{normalized_score.round(2)}"
      normalized_score.round(2)
    end

    # Пакетный расчет для коллекции товаров
    def calculate_batch_optimality(products, options = {})
      return [] if products.empty?
      
      # Находим максимальную цену для нормализации
      max_price = products.maximum(:price_uah) || 1
      options_with_max_price = options.merge(max_price: max_price)
      
      products.map do |product|
        score = calculate_optimality(product, options_with_max_price)
        { product: product, optimality_score: score }
      end.sort_by { |item| -item[:optimality_score] }
    end

    # Обновление рейтингов в базе данных
    def update_optimality_scores(products_scope = nil, options = {})
      products_scope ||= SupplierTireProduct.includes(:tire_brand, :tire_model, :country)
      
      Rails.logger.info "🚀 Начинается обновление рейтингов оптимальности"
      
      batch_size = options[:batch_size] || 1000
      updated_count = 0
      
      products_scope.find_in_batches(batch_size: batch_size) do |batch|
        # Находим максимальную цену в батче
        max_price = batch.map(&:price_uah).compact.max || 1
        batch_options = options.merge(max_price: max_price)
        
        batch.each do |product|
          begin
            score = calculate_optimality(product, batch_options)
            product.update_column(:optimality_score, score)
            updated_count += 1
            
            if updated_count % 100 == 0
              Rails.logger.info "📊 Обновлено рейтингов: #{updated_count}"
            end
          rescue => e
            Rails.logger.error "❌ Ошибка расчета рейтинга для товара #{product.id}: #{e.message}"
            next
          end
        end
      end
      
      Rails.logger.info "🎉 Обновление рейтингов завершено: #{updated_count} товаров"
      updated_count
    end

    private

    # Получение коэффициентов приоритета
    def get_priority_coefficients(priority_type)
      case priority_type
      when 'price_quality', 'соотношение цена/качество'
        PRIORITY_COEFFICIENTS['price_quality']
      when 'prestige', 'престижность'
        PRIORITY_COEFFICIENTS['prestige']
      when 'functionality', 'функциональность'
        PRIORITY_COEFFICIENTS['functionality']
      else
        # Сбалансированный подход - все коэффициенты = 1
        DEFAULT_WEIGHTS.keys.each_with_object({}) { |key, hash| hash[key] = 1 }
      end
    end

    # Расчет оценки бренда (1-10)
    def calculate_brand_score(product)
      return 5 unless product.tire_brand
      
      product.tire_brand.rating_score.to_f
    end

    # Расчет оценки страны производства (1-10)
    def calculate_country_score(product)
      return 5 unless product.country
      
      product.country.rating_score.to_f
    end

    # Расчет оценки индекса скорости
    def calculate_speed_index_score(product)
      return 5 if product.speed_index.blank?
      
      # Извлекаем букву индекса скорости
      speed_letter = product.speed_index.gsub(/[^A-Z]/, '').first
      return 5 unless speed_letter
      
      # Порядковый номер буквы в алфавите
      alphabet_position = speed_letter.ord - 'A'.ord + 1
      
      # Применяем формулу: (позиция/26)*10
      score = (alphabet_position.to_f / 26) * 10
      [score, 10.0].min.round(2)
    end

    # Расчет оценки индекса нагрузки
    def calculate_load_index_score(product)
      return 5 if product.load_index.blank?
      
      # Извлекаем числовое значение
      load_value = product.load_index.to_i
      return 5 if load_value == 0
      
      # Применяем формулу: индекс/12 (максимум 10)
      score = load_value.to_f / 12
      [score, 10.0].min.round(2)
    end

    # Расчет оценки года производства
    def calculate_production_year_score(product)
      return 5 unless product.production_year
      
      current_year = Time.current.year
      year_diff = current_year - product.production_year
      
      # Формула: текущий год = 10, каждый предыдущий год -1 балл
      score = 10 - year_diff
      [score, 0].max.to_f
    end

    # Расчет оценки рейтинга модели
    def calculate_model_rating_score(product)
      return 5 unless product.tire_model
      
      product.tire_model.rating_score.to_f
    end

    # Расчет оценки цены
    def calculate_price_score(product, max_price = nil)
      return 5 if product.price_uah.blank? || product.price_uah <= 0
      
      # Если максимальная цена не передана, используем цену товара
      max_price ||= product.price_uah
      return 10 if max_price <= 0
      
      # Формула: (1 - (цена товара)/(максимальная цена)) * 10
      # Самая дешевая = 10, самая дорогая = 0
      price_ratio = product.price_uah.to_f / max_price.to_f
      score = (1 - price_ratio) * 10
      [score, 0].max.round(2)
    end
  end
end