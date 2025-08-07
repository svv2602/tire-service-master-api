# frozen_string_literal: true

namespace :tire_normalization do
  desc "Нормализация всех товаров поставщиков"
  task normalize_all: :environment do
    puts "🚀 Начинается нормализация всех товаров..."
    
    start_time = Time.current
    TireDataNormalizer.normalize_all_products
    end_time = Time.current
    
    duration = (end_time - start_time).round(2)
    puts "⏱️  Время выполнения: #{duration} секунд"
    
    # Статистика
    total_products = SupplierTireProduct.count
    normalized_products = SupplierTireProduct.normalized.count
    normalization_rate = (normalized_products.to_f / total_products * 100).round(2)
    
    puts "📊 Статистика нормализации:"
    puts "  - Всего товаров: #{total_products}"
    puts "  - Нормализовано: #{normalized_products}"
    puts "  - Процент нормализации: #{normalization_rate}%"
  end

  desc "Расчет рейтингов оптимальности для всех товаров"
  task calculate_optimality: :environment do
    puts "🧮 Начинается расчет рейтингов оптимальности..."
    
    start_time = Time.current
    updated_count = TireOptimalityCalculator.update_optimality_scores
    end_time = Time.current
    
    duration = (end_time - start_time).round(2)
    puts "⏱️  Время выполнения: #{duration} секунд"
    puts "✅ Обновлено рейтингов: #{updated_count}"
  end

  desc "Расчет рейтингов оптимальности с приоритетом"
  task :calculate_optimality_priority, [:priority_type] => :environment do |t, args|
    priority_type = args[:priority_type] || 'balanced'
    valid_types = ['price_quality', 'prestige', 'functionality', 'balanced']
    
    unless valid_types.include?(priority_type)
      puts "❌ Неверный тип приоритета. Доступные: #{valid_types.join(', ')}"
      exit 1
    end
    
    puts "🧮 Расчет рейтингов с приоритетом: #{priority_type}"
    
    start_time = Time.current
    updated_count = TireOptimalityCalculator.update_optimality_scores(
      SupplierTireProduct.normalized,
      priority_type: priority_type
    )
    end_time = Time.current
    
    duration = (end_time - start_time).round(2)
    puts "⏱️  Время выполнения: #{duration} секунд"
    puts "✅ Обновлено рейтингов: #{updated_count}"
  end

  desc "Статистика нормализации"
  task stats: :environment do
    total_products = SupplierTireProduct.count
    normalized_products = SupplierTireProduct.normalized.count
    not_normalized = SupplierTireProduct.not_normalized.count
    with_optimality = SupplierTireProduct.where.not(optimality_score: nil).count
    
    puts "📊 СТАТИСТИКА НОРМАЛИЗАЦИИ ШИН"
    puts "=" * 50
    puts "Всего товаров: #{total_products}"
    puts "Нормализовано: #{normalized_products} (#{(normalized_products.to_f / total_products * 100).round(2)}%)"
    puts "Не нормализовано: #{not_normalized} (#{(not_normalized.to_f / total_products * 100).round(2)}%)"
    puts "С рейтингом оптимальности: #{with_optimality} (#{(with_optimality.to_f / total_products * 100).round(2)}%)"
    puts ""
    
    # Статистика по брендам
    puts "📈 ТОП-10 БРЕНДОВ:"
    TireBrand.joins(:supplier_tire_products)
             .group('tire_brands.name')
             .order('count_all DESC')
             .limit(10)
             .count
             .each_with_index do |(brand, count), index|
               puts "  #{index + 1}. #{brand}: #{count} товаров"
             end
    puts ""
    
    # Статистика по странам
    puts "🌍 ТОП-5 СТРАН ПРОИЗВОДСТВА:"
    Country.joins(:supplier_tire_products)
           .group('countries.name')
           .order('count_all DESC')
           .limit(5)
           .count
           .each_with_index do |(country, count), index|
             puts "  #{index + 1}. #{country}: #{count} товаров"
           end
    puts ""
    
    # Статистика рейтингов
    if with_optimality > 0
      avg_rating = SupplierTireProduct.where.not(optimality_score: nil).average(:optimality_score).round(2)
      max_rating = SupplierTireProduct.maximum(:optimality_score)
      min_rating = SupplierTireProduct.minimum(:optimality_score)
      
      puts "⭐ РЕЙТИНГИ ОПТИМАЛЬНОСТИ:"
      puts "  Средний рейтинг: #{avg_rating}"
      puts "  Максимальный рейтинг: #{max_rating}"
      puts "  Минимальный рейтинг: #{min_rating}"
      
      # Распределение по рейтингам
      puts ""
      puts "📊 РАСПРЕДЕЛЕНИЕ ПО РЕЙТИНГАМ:"
      [
        [9..10, "Отличные (9-10)"],
        [7..8.99, "Хорошие (7-8.99)"],
        [5..6.99, "Средние (5-6.99)"],
        [0..4.99, "Ниже среднего (0-4.99)"]
      ].each do |range, label|
        count = SupplierTireProduct.where(optimality_score: range).count
        percentage = (count.to_f / with_optimality * 100).round(2)
        puts "  #{label}: #{count} товаров (#{percentage}%)"
      end
    end
  end

  desc "Очистка данных нормализации"
  task reset: :environment do
    print "⚠️  Вы уверены, что хотите очистить все данные нормализации? [y/N]: "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "❌ Операция отменена"
      exit 0
    end
    
    puts "🧹 Очистка данных нормализации..."
    
    # Обнуляем связи с нормализованными данными
    SupplierTireProduct.update_all(
      tire_brand_id: nil,
      tire_model_id: nil,
      country_id: nil,
      production_year: nil,
      optimality_score: nil
    )
    
    # Удаляем справочные данные
    TireModel.delete_all
    TireBrand.delete_all
    Country.delete_all
    
    puts "✅ Данные нормализации очищены"
    puts "💡 Запустите 'rails runner db/seeds/tire_normalization_seeds.rb' для восстановления базовых справочников"
  end

  desc "Полная нормализация и расчет рейтингов"
  task full_process: :environment do
    puts "🚀 ПОЛНЫЙ ПРОЦЕСС НОРМАЛИЗАЦИИ И ОЦЕНКИ"
    puts "=" * 50
    
    start_time = Time.current
    
    # Шаг 1: Нормализация
    puts "1️⃣ Нормализация товаров..."
    Rake::Task['tire_normalization:normalize_all'].invoke
    
    # Шаг 2: Расчет рейтингов
    puts "\n2️⃣ Расчет рейтингов оптимальности..."
    Rake::Task['tire_normalization:calculate_optimality'].invoke
    
    # Шаг 3: Статистика
    puts "\n3️⃣ Итоговая статистика:"
    Rake::Task['tire_normalization:stats'].invoke
    
    end_time = Time.current
    total_duration = (end_time - start_time).round(2)
    
    puts "\n🎉 ПРОЦЕСС ЗАВЕРШЕН!"
    puts "⏱️  Общее время выполнения: #{total_duration} секунд"
  end

  desc "Тестирование нормализации на небольшой выборке"
  task test: :environment do
    puts "🧪 Тестирование нормализации на 10 товарах..."
    
    test_products = SupplierTireProduct.not_normalized.limit(10)
    
    if test_products.empty?
      puts "❌ Нет товаров для тестирования (все уже нормализованы)"
      exit 0
    end
    
    test_products.each_with_index do |product, index|
      puts "\n#{index + 1}. Товар ID #{product.id}:"
      puts "   Оригинал: #{product.original_brand} #{product.original_model} (#{product.original_country})"
      
      # Нормализуем
      TireDataNormalizer.normalize_product(product)
      product.reload
      
      puts "   Нормализовано: #{product.tire_brand&.name || 'НЕ НАЙДЕН'} #{product.tire_model&.name || 'НЕ НАЙДЕНА'} (#{product.country&.name || 'НЕ НАЙДЕНА'})"
      
      # Рассчитываем рейтинг
      score = product.calculate_optimality_score
      puts "   Рейтинг оптимальности: #{score}"
    end
    
    puts "\n✅ Тестирование завершено"
  end
end