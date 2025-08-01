namespace :tire_data do
  desc "Обновление данных шин из CSV файлов"
  task :update, [:csv_path, :version] => :environment do |t, args|
    csv_path = args[:csv_path] || ENV['CSV_PATH']
    version = args[:version] || ENV['DATA_VERSION']
    
    unless csv_path
      puts "❌ Не указан путь к CSV файлам"
      puts "Использование: rails tire_data:update[/path/to/csv/files,2025.2]"
      puts "Или установите переменную окружения: CSV_PATH=/path/to/csv/files"
      exit 1
    end
    
    unless Dir.exist?(csv_path)
      puts "❌ Папка не найдена: #{csv_path}"
      exit 1
    end
    
    puts "🔄 Начинаем обновление данных шин..."
    puts "📁 Источник: #{csv_path}"
    puts "📋 Версия: #{version || 'автоматическая'}"
    puts ""
    
    begin
      processor = TireData::Processor.new(csv_path, version)
      result = processor.process_and_update
      
      if result[:success]
        puts ""
        puts "✅ Обновление завершено успешно!"
        puts "📊 Статистика:"
        result[:statistics].each do |key, value|
          puts "   #{key}: #{value}"
        end
        puts ""
        puts "🎯 Версия данных: #{result[:version]}"
      else
        puts "❌ Обновление не выполнено: #{result[:message]}"
        exit 1
      end
      
    rescue => e
      puts "❌ Ошибка при обновлении данных:"
      puts "   #{e.message}"
      puts ""
      puts "🔍 Проверьте:"
      puts "   - Корректность пути к CSV файлам"
      puts "   - Наличие всех необходимых файлов (brand, model, kit, kit_tyre_size)"
      puts "   - Формат CSV файлов (UTF-8, с заголовками)"
      puts "   - Подключение к базе данных"
      exit 1
    end
  end
  
  desc "Миграция CSV данных в seed файлы"
  task :migrate, [:csv_path, :output_path, :sample_size] => :environment do |t, args|
    csv_path = args[:csv_path] || ENV['CSV_PATH']
    output_path = args[:output_path] || Rails.root.join('db', 'seeds')
    sample_size = args[:sample_size]&.to_i
    
    unless csv_path
      puts "❌ Не указан путь к CSV файлам"
      puts "Использование: rails tire_data:migrate[/path/to/csv/files,db/seeds,1000]"
      exit 1
    end
    
    puts "🔄 Начинаем миграцию CSV данных в seed файлы..."
    puts "📁 Источник: #{csv_path}"
    puts "📝 Назначение: #{output_path}"
    puts "📊 Образец: #{sample_size || 'все данные'}"
    puts ""
    
    begin
      migrator = TireData::Migrator.new(csv_path, output_path)
      
      result = if sample_size
        migrator.migrate_sample!(sample_size)
      else
        migrator.migrate!
      end
      
      if result[:success]
        puts ""
        puts "✅ Миграция завершена успешно!"
        puts "📊 Статистика:"
        result[:statistics].each do |key, value|
          puts "   #{key}: #{value}"
        end
        puts ""
        puts "📝 Созданные seed файлы:"
        puts "   - tire_brands_processed.rb"
        puts "   - tire_models_processed.rb"
        puts "   - tire_configurations_full.rb"
        puts "   - tire_search_aliases.rb"
        puts ""
        puts "💡 Для загрузки данных используйте:"
        puts "   rails db:seed SEED=tire_brands_processed"
        puts "   rails db:seed SEED=tire_models_processed"
        puts "   rails db:seed SEED=tire_configurations_full"
      end
      
    rescue => e
      puts "❌ Ошибка при миграции:"
      puts "   #{e.message}"
      exit 1
    end
  end
  
  desc "Откат к предыдущей версии данных"
  task :rollback, [:version] => :environment do |t, args|
    target_version = args[:version]
    
    if target_version.blank?
      puts "❌ Не указана версия для отката"
      puts "Использование: rails tire_data:rollback[2025.1]"
      puts ""
      puts "📋 Доступные версии:"
      TireDataVersion.order(:imported_at).each do |version|
        status = version.is_active? ? "🟢 активная" : "⚪ неактивная"
        puts "   #{version.version} - #{version.imported_at.strftime('%d.%m.%Y %H:%M')} (#{status})"
      end
      exit 1
    end
    
    target = TireDataVersion.find_by(version: target_version)
    unless target
      puts "❌ Версия #{target_version} не найдена"
      exit 1
    end
    
    current = TireDataVersion.current
    if current&.version == target_version
      puts "⚠️ Версия #{target_version} уже активна"
      exit 0
    end
    
    puts "🔄 Выполняем откат к версии #{target_version}..."
    puts "📊 Текущая версия: #{current&.version || 'нет'}"
    puts ""
    
    begin
      result = TireDataVersion.rollback_to_version!(target_version)
      
      puts "✅ Откат выполнен успешно!"
      puts "📋 Активная версия: #{result.version}"
      puts "📊 Конфигураций: #{result.active_configurations_count}"
      
    rescue => e
      puts "❌ Ошибка при откате:"
      puts "   #{e.message}"
      exit 1
    end
  end
  
  desc "Просмотр версий данных"
  task :versions => :environment do
    versions = TireDataVersion.order(:imported_at)
    
    if versions.empty?
      puts "📋 Версии данных не найдены"
      exit 0
    end
    
    puts "📋 Версии данных шин:"
    puts ""
    
    versions.each do |version|
      status = version.is_active? ? "🟢 АКТИВНАЯ" : "⚪ неактивная"
      
      puts "#{status} #{version.version}"
      puts "   📅 Импортирована: #{version.imported_at.strftime('%d.%m.%Y %H:%M')}"
      puts "   📊 Конфигураций: #{version.configurations_count}"
      puts "   📝 Описание: #{version.source_description}"
      
      if version.statistics
        puts "   📈 Статистика:"
        version.statistics.each do |key, value|
          puts "      #{key}: #{value}"
        end
      end
      
      puts "   🗄️ Размер файлов: #{version.formatted_file_size}"
      puts "   ⏰ Возраст: #{version.age_in_days} дней"
      puts ""
    end
    
    current = TireDataVersion.current
    puts "🎯 Текущая версия: #{current&.version || 'нет'}"
    puts "📊 Общая статистика: #{TireDataVersion.version_statistics}"
  end
  
  desc "Очистка устаревших данных"
  task :cleanup, [:keep_versions] => :environment do |t, args|
    keep_versions = args[:keep_versions]&.to_i || 5
    
    puts "🧹 Очистка устаревших версий данных..."
    puts "📊 Сохраняем последних версий: #{keep_versions}"
    puts ""
    
    versions_before = TireDataVersion.count
    configs_before = CarTireConfiguration.count
    
    begin
      TireDataVersion.cleanup_old_versions!(keep_versions)
      
      versions_after = TireDataVersion.count
      configs_after = CarTireConfiguration.count
      
      puts "✅ Очистка завершена!"
      puts "📊 Удалено версий: #{versions_before - versions_after}"
      puts "📊 Удалено конфигураций: #{configs_before - configs_after}"
      puts "💾 Освобождено места в БД"
      
    rescue => e
      puts "❌ Ошибка при очистке:"
      puts "   #{e.message}"
      exit 1
    end
  end
  
  desc "Генерация seed файлов из текущих данных"
  task :generate_seeds, [:output_path] => :environment do |t, args|
    output_path = args[:output_path] || Rails.root.join('db', 'seeds')
    
    puts "📝 Генерируем seed файлы из текущих данных..."
    puts "📁 Назначение: #{output_path}"
    puts ""
    
    FileUtils.mkdir_p(output_path) unless Dir.exist?(output_path)
    
    # Генерируем seed файл с текущими конфигурациями
    configs = CarTireConfiguration.active.not_deprecated.includes(:brand, :model)
    
    if configs.empty?
      puts "⚠️ Нет активных конфигураций для экспорта"
      exit 0
    end
    
    file_path = File.join(output_path, 'tire_configurations_export.rb')
    
    File.open(file_path, 'w') do |file|
      file.puts "# Экспорт текущих конфигураций шин"
      file.puts "# Сгенерировано: #{Time.current}"
      file.puts "# Версия данных: #{TireDataVersion.current&.version}"
      file.puts ""
      file.puts "puts '=== Загрузка экспортированных конфигураций шин ==='"
      file.puts ""
      file.puts "configurations = ["
      
      configs.each do |config|
        file.puts "  {"
        file.puts "    brand_name: #{config.brand.name.inspect},"
        file.puts "    model_name: #{config.model.name.inspect},"
        file.puts "    year_from: #{config.year_from},"
        file.puts "    year_to: #{config.year_to},"
        file.puts "    tire_sizes: #{config.tire_sizes.inspect},"
        file.puts "    search_aliases: #{config.search_aliases.inspect},"
        file.puts "    search_tokens: #{config.search_tokens.inspect}"
        file.puts "  },"
      end
      
      file.puts "]"
      file.puts ""
      file.puts "current_version = TireDataVersion.current&.version || 'exported'"
      file.puts "created_count = 0"
      file.puts ""
      file.puts "configurations.each do |config_data|"
      file.puts "  brand = CarBrand.find_by(name: config_data[:brand_name])"
      file.puts "  model = CarModel.find_by(brand: brand, name: config_data[:model_name]) if brand"
      file.puts "  next unless brand && model"
      file.puts ""
      file.puts "  config = CarTireConfiguration.find_or_create_by("
      file.puts "    brand: brand,"
      file.puts "    model: model,"
      file.puts "    year_from: config_data[:year_from],"
      file.puts "    year_to: config_data[:year_to]"
      file.puts "  ) do |c|"
      file.puts "    c.tire_sizes = config_data[:tire_sizes]"
      file.puts "    c.search_aliases = config_data[:search_aliases]"
      file.puts "    c.search_tokens = config_data[:search_tokens]"
      file.puts "    c.data_version = current_version"
      file.puts "    c.source_file = 'seeds/tire_configurations_export.rb'"
      file.puts "    c.last_updated = Time.current"
      file.puts "    c.is_active = true"
      file.puts "    c.is_deprecated = false"
      file.puts "  end"
      file.puts ""
      file.puts "  created_count += 1"
      file.puts "  puts \"✓ \#{config.full_name}\" if created_count % 50 == 0"
      file.puts "end"
      file.puts ""
      file.puts "puts \"✅ Экспортировано конфигураций: \#{created_count}\""
    end
    
    puts "✅ Seed файл создан: #{file_path}"
    puts "📊 Экспортировано конфигураций: #{configs.size}"
    puts ""
    puts "💡 Для загрузки используйте:"
    puts "   rails db:seed SEED=tire_configurations_export"
  end
  
  desc "Проверка целостности данных"
  task :validate => :environment do
    puts "🔍 Проверка целостности данных шин..."
    puts ""
    
    errors = []
    warnings = []
    
    # Проверяем версии
    versions = TireDataVersion.all
    active_versions = versions.select(&:is_active?)
    
    if active_versions.empty?
      errors << "Нет активных версий данных"
    elsif active_versions.size > 1
      errors << "Несколько активных версий: #{active_versions.map(&:version).join(', ')}"
    end
    
    # Проверяем конфигурации
    configs = CarTireConfiguration.all
    active_configs = configs.select(&:is_active?)
    deprecated_configs = configs.select(&:is_deprecated?)
    
    if active_configs.empty?
      errors << "Нет активных конфигураций шин"
    end
    
    # Проверяем связи
    configs_without_brand = configs.select { |c| c.brand.nil? rescue true }
    configs_without_model = configs.select { |c| c.model.nil? rescue true }
    
    errors.concat(configs_without_brand.map { |c| "Конфигурация #{c.id} без бренда" })
    errors.concat(configs_without_model.map { |c| "Конфигурация #{c.id} без модели" })
    
    # Проверяем данные шин
    configs.each do |config|
      if config.tire_sizes.blank?
        errors << "Конфигурация #{config.id} без размеров шин"
      elsif !config.tire_sizes.is_a?(Array)
        errors << "Конфигурация #{config.id}: tire_sizes не является массивом"
      end
      
      if config.year_from && config.year_to && config.year_from > config.year_to
        errors << "Конфигурация #{config.id}: некорректный диапазон лет"
      end
    end
    
    # Проверяем поисковые токены
    configs_without_tokens = configs.select { |c| c.search_tokens.blank? }
    warnings.concat(configs_without_tokens.map { |c| "Конфигурация #{c.id} без поисковых токенов" })
    
    # Выводим результаты
    puts "📊 Статистика:"
    puts "   Всего версий: #{versions.size}"
    puts "   Активных версий: #{active_versions.size}"
    puts "   Всего конфигураций: #{configs.size}"
    puts "   Активных конфигураций: #{active_configs.size}"
    puts "   Устаревших конфигураций: #{deprecated_configs.size}"
    puts ""
    
    if errors.any?
      puts "❌ Найдены ошибки:"
      errors.each { |error| puts "   • #{error}" }
      puts ""
    end
    
    if warnings.any?
      puts "⚠️ Предупреждения:"
      warnings.each { |warning| puts "   • #{warning}" }
      puts ""
    end
    
    if errors.empty? && warnings.empty?
      puts "✅ Проверка пройдена успешно! Данные в порядке."
    elsif errors.empty?
      puts "✅ Критических ошибок не найдено. Есть предупреждения."
    else
      puts "❌ Найдены критические ошибки в данных!"
      exit 1
    end
  end
  
  desc "Статистика по поиску шин"
  task :search_stats => :environment do
    puts "📊 Статистика системы поиска шин:"
    puts ""
    
    # Общая статистика
    stats = TireDataVersion.version_statistics
    current_version = TireDataVersion.current
    
    puts "🎯 Текущая версия: #{current_version&.version || 'нет'}"
    puts "📅 Последнее обновление: #{current_version&.imported_at&.strftime('%d.%m.%Y %H:%M') || 'нет'}"
    puts ""
    
    puts "📈 Общие показатели:"
    stats.each do |key, value|
      puts "   #{key}: #{value}"
    end
    puts ""
    
    # Статистика по брендам
    brand_stats = CarTireConfiguration.active
                                     .joins(:brand)
                                     .group('car_brands.name')
                                     .count
                                     .sort_by { |_, count| -count }
    
    puts "🚗 Топ-10 брендов по количеству конфигураций:"
    brand_stats.first(10).each do |brand, count|
      puts "   #{brand}: #{count}"
    end
    puts ""
    
    # Статистика по диаметрам
    diameter_stats = {}
    CarTireConfiguration.active.find_each do |config|
      config.all_diameters.each do |diameter|
        diameter_stats[diameter] = (diameter_stats[diameter] || 0) + 1
      end
    end
    
    puts "⚙️ Популярные диаметры шин:"
    diameter_stats.sort_by { |_, count| -count }.first(10).each do |diameter, count|
      puts "   R#{diameter}: #{count} конфигураций"
    end
    puts ""
    
    # Статистика по годам
    year_ranges = CarTireConfiguration.active.pluck(:year_from, :year_to)
    min_year = year_ranges.map(&:first).min
    max_year = year_ranges.map(&:last).max
    
    puts "📅 Охват по годам: #{min_year} - #{max_year}"
    puts "📊 Средний диапазон лет на конфигурацию: #{year_ranges.map { |from, to| to - from + 1 }.sum.to_f / year_ranges.size}"
  end

  desc "Безопасная очистка и перезагрузка данных (НЕ для продакшена)"
  task :clear_and_reload, [:csv_path, :version] => :environment do |t, args|
    # Проверяем окружение
    if Rails.env.production?
      puts "🚨 ОПАСНОСТЬ: Эта задача запрещена в продакшене!"
      puts "💡 Используйте обычное обновление: rails tire_data:update[path,version]"
      exit 1
    end
    
    csv_path = args[:csv_path] || ENV['CSV_PATH']
    version = args[:version] || ENV['DATA_VERSION']
    
    unless csv_path
      puts "❌ Не указан путь к CSV файлам"
      puts "Использование: rails tire_data:clear_and_reload[/path/to/csv/files,2025.2]"
      exit 1
    end
    
    unless Dir.exist?(csv_path)
      puts "❌ Папка не найдена: #{csv_path}"
      exit 1
    end
    
    puts "🔄 БЕЗОПАСНАЯ ОЧИСТКА И ПЕРЕЗАГРУЗКА ДАННЫХ"
    puts "⚠️  Сохраняются бренды и модели, используемые в бронированиях"
    puts "🚫 Запрещено в продакшене для безопасности данных"
    puts "📁 Источник: #{csv_path}"
    puts "📋 Версия: #{version || 'автоматическая'}"
    puts ""
    
    # Показываем что будет сохранено
    puts "🔍 Проверяем используемые данные..."
    used_bookings = 0
    used_client_cars = 0
    
    begin
      used_bookings = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM bookings WHERE car_brand IS NOT NULL OR car_model IS NOT NULL").first['count'].to_i if ActiveRecord::Base.connection.table_exists?('bookings')
      used_client_cars = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM client_cars WHERE brand_id IS NOT NULL OR model_id IS NOT NULL").first['count'].to_i if ActiveRecord::Base.connection.table_exists?('client_cars')
    rescue => e
      puts "⚠️  Не удалось проверить используемые данные: #{e.message}"
    end
    
    puts "📊 Найдено записей с автомобилями:"
    puts "   Бронирования: #{used_bookings}"
    puts "   Автомобили клиентов: #{used_client_cars}"
    puts ""
    
    if used_bookings > 0 || used_client_cars > 0
      puts "⚠️  ВНИМАНИЕ: Некоторые бренды и модели будут сохранены!"
      puts "💡 Для полной очистки используйте тестовую базу данных"
      puts ""
    end
    
    begin
      # Создаем процессор с опцией force_reload
      processor = TireData::Processor.new(csv_path, version, { 
        force_reload: true,
        skip_invalid_rows: true,
        fix_suspicious_sizes: true
      })
      result = processor.process_and_update
      
      if result[:success]
        puts ""
        puts "✅ Безопасная перезагрузка завершена успешно!"
        puts "📊 Статистика:"
        result[:statistics].each do |key, value|
          puts "   #{key}: #{value}"
        end
        puts ""
        puts "🎯 Версия данных: #{result[:version]}"
        
        if result[:statistics][:preserved_data]
          puts ""
          puts "🛡️  Сохранено используемых данных:"
          result[:statistics][:preserved_data].each do |key, value|
            puts "   #{key}: #{value}"
          end
        end
      else
        puts "❌ Перезагрузка не выполнена: #{result[:message]}"
        exit 1
      end
      
    rescue => e
      puts "❌ Ошибка при перезагрузке данных:"
      puts "   #{e.message}"
      exit 1
    end
  end

  desc "Очистить модели с названиями брендов"
  task :clean_brand_name_models, [:force] => :environment do |t, args|
    force_mode = args[:force] == 'true' || args[:force] == 'force'
    
    puts "🧹 ОЧИСТКА МОДЕЛЕЙ С НАЗВАНИЯМИ БРЕНДОВ"
    puts "🔧 Режим: #{force_mode ? 'ПРИНУДИТЕЛЬНЫЙ (удаляем все)' : 'БЕЗОПАСНЫЙ (только явно проблемные)'}"
    puts ""
    
    # Получаем все названия брендов
    brand_names = CarBrand.pluck(:name).map(&:strip).uniq
    puts "📋 Всего брендов: #{brand_names.count}"
    
    # Находим модели, которые совпадают с названиями брендов
    problematic_models = CarModel.joins(:brand).where(name: brand_names)
    puts "🔍 Найдено проблемных моделей: #{problematic_models.count}"
    
    if problematic_models.count == 0
      puts "✅ Проблемных моделей не найдено!"
      return
    end
    
    # Показываем детали
    puts "\n📋 АНАЛИЗ ПРОБЛЕМНЫХ МОДЕЛЕЙ:"
    grouped = problematic_models.includes(:brand).group_by(&:brand)
    
    confirmed_problematic = []
    potentially_valid = []
    
    grouped.each do |brand, models|
      models.each do |model|
        # Проверяем, является ли название модели явно проблемным
        if is_clearly_problematic_model?(brand.name, model.name, brand_names)
          confirmed_problematic << model
          puts "  ❌ #{brand.name} -> #{model.name} (УДАЛИТЬ - это бренд)"
        else
          potentially_valid << model
          puts "  ⚠️  #{brand.name} -> #{model.name} (ПРОВЕРИТЬ - может быть реальной моделью)"
        end
      end
    end
    
    puts "\n🎯 СТАТИСТИКА:"
    puts "  Явно проблемных: #{confirmed_problematic.count}"
    puts "  Требуют проверки: #{potentially_valid.count}"
    
    # Удаляем явно проблемные модели
    if confirmed_problematic.any?
      puts "\n🗑️  Удаляем явно проблемные модели..."
      confirmed_problematic.each do |model|
        puts "    Удаляем: #{model.brand.name} -> #{model.name}"
        model.destroy
      end
      puts "✅ Удалено #{confirmed_problematic.count} явно проблемных моделей"
    end
    
    # Обрабатываем спорные модели
    if potentially_valid.any?
      if force_mode
        puts "\n🔥 ПРИНУДИТЕЛЬНОЕ УДАЛЕНИЕ спорных моделей..."
        potentially_valid.each do |model|
          puts "    Удаляем: #{model.brand.name} -> #{model.name}"
          model.destroy
        end
        puts "✅ Удалено #{potentially_valid.count} спорных моделей"
      else
        puts "\n⚠️  ТРЕБУЮТ РУЧНОЙ ПРОВЕРКИ:"
        potentially_valid.each do |model|
          puts "    #{model.brand.name} -> #{model.name}"
        end
        puts "\n💡 Для удаления спорных моделей используйте:"
        puts "   rails tire_data:clean_brand_name_models[force]"
      end
    end
    
    total_removed = confirmed_problematic.count + (force_mode ? potentially_valid.count : 0)
    puts "\n🎉 ИТОГО УДАЛЕНО: #{total_removed} моделей"
  end

  # Вспомогательная функция для определения явно проблемных моделей
  def is_clearly_problematic_model?(brand_name, model_name, all_brand_names)
    # Список явно проблемных случаев (дочерние бренды как модели родительских)
    problematic_cases = {
      'Mitsubishi' => ['Jeep'],
      'Nissan' => ['Datsun', 'Infiniti'], 
      'Hyundai' => ['Genesis', 'Kia'],
      'Jiangling' => ['Landwind'],
      'Toyota' => ['Lexus', 'Scion'],
      'Volkswagen' => ['Audi', 'Bentley', 'Bugatti', 'Lamborghini', 'Porsche', 'Seat', 'Skoda'],
      'General Motors' => ['Buick', 'Cadillac', 'Chevrolet', 'GMC', 'Opel', 'Vauxhall'],
      'Ford' => ['Lincoln', 'Mercury'],
      'Chrysler' => ['Dodge', 'Jeep', 'Ram'],
      'BMW' => ['MINI', 'Rolls-Royce'],
      'Tata' => ['Jaguar', 'Land Rover'],
      'Geely' => ['Volvo', 'Lotus', 'Polestar']
    }
    
    # Проверяем явные случаи дочерних брендов
    if problematic_cases[brand_name]&.include?(model_name)
      return true
    end
    
    # Проверяем, если название модели точно совпадает с названием бренда
    # и это не тот же бренд (например, Ford Focus vs Ford как модель Ford)
    if all_brand_names.include?(model_name) && brand_name != model_name
      # Исключения - модели, которые могут совпадать с брендами но являются реальными моделями
      valid_coincidences = [
        'Jetta',      # Реальная модель Volkswagen, хотя есть и бренд Jetta
        'ZX',         # Реальная модель Citroen и MG
        'Tank',       # Может быть реальной моделью Toyota
        'Victory',    # Может быть реальной моделью
        'Emgrand',    # Реальная модель Geely
        'Gratour'     # Может быть реальной моделью Foton
      ]
      return !valid_coincidences.include?(model_name)
    end
    
    false
  end
end