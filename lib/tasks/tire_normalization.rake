# frozen_string_literal: true

namespace :tire_normalization do
  desc "Запуск полной нормализации данных шин"
  task normalize_all: :environment do
    puts "🚀 ЗАПУСК НОРМАЛИЗАЦИИ ДАННЫХ ШИН"
    puts "=" * 50
    
    # Проверяем наличие справочников
    check_references_availability
    
    # Запускаем нормализацию
    service = TireNormalizationService.new(batch_size: 200)
    stats = service.normalize_all_products!
    
    puts "\n🎯 ИТОГОВЫЕ РЕЗУЛЬТАТЫ:"
    puts "  Обработано: #{stats[:processed]} товаров"
    puts "  Нормализовано брендов: #{stats[:normalized_brands]}"
    puts "  Нормализовано моделей: #{stats[:normalized_models]}"
    puts "  Нормализовано стран: #{stats[:normalized_countries]}"
    puts "  Ошибок: #{stats[:failed]}"
  end

  desc "Нормализация только не обработанных товаров"
  task normalize_new: :environment do
    puts "🔄 НОРМАЛИЗАЦИЯ ТОЛЬКО НОВЫХ ТОВАРОВ"
    puts "=" * 50
    
    # Товары без нормализованных данных
    scope = SupplierTireProduct.where(
      tire_brand_id: nil,
      tire_model_id: nil,
      country_id: nil
    )
    
    count = scope.count
    puts "📊 Товаров для нормализации: #{count}"
    
    if count.zero?
      puts "✅ Все товары уже нормализованы!"
      next
    end
    
    service = TireNormalizationService.new(batch_size: 100)
    scope.find_in_batches(batch_size: 100) do |batch|
      batch.each { |product| service.normalize_product(product) }
    end
    
    puts "✅ Нормализация новых товаров завершена!"
  end

  desc "Создание справочников из существующих данных"
  task create_references: :environment do
    puts "📚 СОЗДАНИЕ СПРАВОЧНИКОВ ИЗ ДАННЫХ"
    puts "=" * 50
    
    # Сначала загружаем существующие сиды
    load_seeds_if_needed
    
    # Затем создаем недостающие записи
    create_missing_brands
    create_missing_models
    
    puts "✅ Создание справочников завершено!"
  end

  desc "Обновление рейтингов оптимальности"
  task update_optimality: :environment do
    puts "🎯 ОБНОВЛЕНИЕ РЕЙТИНГОВ ОПТИМАЛЬНОСТИ"
    puts "=" * 50
    
    service = TireNormalizationService.new
    updated = 0
    
    SupplierTireProduct.where(optimality_score: nil).find_each do |product|
      score = service.send(:calculate_optimality_score, product)
      product.update_column(:optimality_score, score)
      updated += 1
      
      if updated % 100 == 0
        puts "  📈 Обновлено: #{updated} товаров"
      end
    end
    
    puts "✅ Обновлено рейтингов: #{updated}"
  end

  desc "Статистика нормализации"
  task stats: :environment do
    puts "📊 СТАТИСТИКА НОРМАЛИЗАЦИИ"
    puts "=" * 50
    
    total = SupplierTireProduct.count
    with_brand = SupplierTireProduct.where.not(tire_brand_id: nil).count
    with_model = SupplierTireProduct.where.not(tire_model_id: nil).count
    with_country = SupplierTireProduct.where.not(country_id: nil).count
    with_score = SupplierTireProduct.where.not(optimality_score: nil).count
    
    puts "📦 Всего товаров: #{total}"
    puts ""
    puts "🔗 НОРМАЛИЗАЦИЯ:"
    puts "  🏷️ С брендом: #{with_brand}/#{total} (#{percentage(with_brand, total)}%)"
    puts "  🚗 С моделью: #{with_model}/#{total} (#{percentage(with_model, total)}%)"
    puts "  🌍 Со страной: #{with_country}/#{total} (#{percentage(with_country, total)}%)"
    puts "  🎯 С рейтингом: #{with_score}/#{total} (#{percentage(with_score, total)}%)"
    puts ""
    puts "📚 СПРАВОЧНИКИ:"
    puts "  🌍 Стран: #{Country.count}"
    puts "  🏷️ Брендов: #{TireBrand.count}"
    puts "  🚗 Моделей: #{TireModel.count}"
    
    # Топ необработанных брендов
    puts ""
    puts "🔍 ТОП-10 НЕОБРАБОТАННЫХ БРЕНДОВ:"
    unprocessed = SupplierTireProduct
      .where(tire_brand_id: nil)
      .group(:original_brand)
      .count
      .sort_by { |_, count| -count }
      .first(10)
    
    unprocessed.each_with_index do |(brand, count), index|
      puts "  #{index + 1}. #{brand} (#{count} товаров)"
    end
  end

  private

  def check_references_availability
    countries_count = Country.count
    brands_count = TireBrand.count
    
    puts "📚 СПРАВОЧНИКИ:"
    puts "  🌍 Стран: #{countries_count}"
    puts "  🏷️ Брендов: #{brands_count}"
    
    if countries_count.zero? || brands_count.zero?
      puts "⚠️ ПРЕДУПРЕЖДЕНИЕ: Справочники пусты!"
      puts "💡 Запустите: rails db:seed:replant"
      return false
    end
    
    puts "✅ Справочники готовы к использованию"
    true
  end

  def load_seeds_if_needed
    if Country.count.zero? || TireBrand.count.zero?
      puts "📥 Загрузка базовых справочников..."
      Rails.application.load_seed
    end
  end

  def create_missing_brands
    puts "🏷️ Создание недостающих брендов..."
    
    # Получаем все бренды из товаров, которых нет в справочнике
    existing_brands = TireBrand.pluck(:normalized_name)
    
    missing_brands = SupplierTireProduct
      .distinct
      .pluck(:original_brand)
      .compact
      .reject { |brand| 
        normalized = TireBrand.send(:normalize_string, brand)
        existing_brands.include?(normalized)
      }
    
    created = 0
    missing_brands.each do |brand_name|
      next if brand_name.blank?
      
      # Определяем страну и рейтинг по умолчанию
      country = guess_brand_country(brand_name)
      rating = guess_brand_rating(brand_name)
      
      tire_brand = TireBrand.create!(
        name: brand_name,
        country: country,
        rating_score: rating,
        is_premium: rating >= 8,
        aliases: [brand_name]
      )
      
      created += 1
      puts "  ✅ Создан бренд: #{tire_brand.name} (рейтинг: #{rating})"
    end
    
    puts "📊 Создано новых брендов: #{created}"
  end

  def create_missing_models
    puts "🚗 Создание недостающих моделей..."
    
    created = 0
    TireBrand.includes(:tire_models).each do |brand|
      existing_models = brand.tire_models.pluck(:normalized_name)
      
      missing_models = SupplierTireProduct
        .joins(:tire_brand)
        .where(tire_brand: brand)
        .distinct
        .pluck(:original_model)
        .compact
        .reject { |model|
          normalized = TireModel.send(:normalize_string, model)
          existing_models.include?(normalized)
        }
      
      missing_models.each do |model_name|
        next if model_name.blank?
        
        # Определяем сезонность модели
        season = guess_model_season(model_name)
        
        tire_model = brand.tire_models.create!(
          name: model_name,
          season_type: season,
          rating_score: 5, # Средний рейтинг по умолчанию
          aliases: [model_name]
        )
        
        created += 1
        puts "  ✅ Создана модель: #{brand.name} #{tire_model.name} (#{season})"
      end
    end
    
    puts "📊 Создано новых моделей: #{created}"
  end

  def guess_brand_country(brand_name)
    # Простая эвристика для определения страны бренда
    case brand_name.downcase
    when /michelin|kleber|cooper/ then Country.find_by(iso_code: 'FR')
    when /continental|uniroyal/ then Country.find_by(iso_code: 'DE')
    when /pirelli/ then Country.find_by(iso_code: 'IT')
    when /goodyear|firestone|general/ then Country.find_by(iso_code: 'US')
    when /nokian/ then Country.find_by(iso_code: 'FI')
    when /hankook|nexen|kumho/ then Country.find_by(iso_code: 'KR')
    when /bridgestone|toyo|yokohama|falken/ then Country.find_by(iso_code: 'JP')
    else nil
    end
  end

  def guess_brand_rating(brand_name)
    # Простая эвристика для определения рейтинга
    premium_brands = %w[michelin continental pirelli nokian bridgestone goodyear]
    high_brands = %w[dunlop vredestein falken yokohama toyo cooper]
    
    normalized = brand_name.downcase
    
    if premium_brands.any? { |premium| normalized.include?(premium) }
      9
    elsif high_brands.any? { |high| normalized.include?(high) }
      7
    else
      5
    end
  end

  def guess_model_season(model_name)
    winter_keywords = %w[winter ice snow hakka alpin x-ice blizzak snowproof krisalp wintrac]
    summer_keywords = %w[sport pilot eagle asymmetric primacy energy pilot]
    
    normalized = model_name.downcase
    
    if winter_keywords.any? { |keyword| normalized.include?(keyword) }
      'winter'
    elsif summer_keywords.any? { |keyword| normalized.include?(keyword) }
      'summer'
    else
      'all_season'
    end
  end

  def percentage(part, total)
    return 0 if total.zero?
    (part.to_f / total * 100).round(1)
  end
end