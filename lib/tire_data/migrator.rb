module TireData
  class Migrator
    attr_reader :csv_directory, :output_directory, :statistics
    
    def initialize(csv_directory, output_directory = nil)
      @csv_directory = csv_directory
      @output_directory = output_directory || Rails.root.join('db', 'seeds')
      @statistics = {}
      @processed_data = {
        brands: {},
        models: {},
        configurations: []
      }
    end
    
    # Основной метод миграции данных из CSV в агрегированный формат
    def migrate!
      Rails.logger.info "🔄 Начинаем миграцию данных из #{@csv_directory}"
      
      validate_input_files
      process_csv_data
      aggregate_data
      generate_seed_files
      generate_statistics
      
      Rails.logger.info "✅ Миграция завершена успешно"
      
      {
        success: true,
        statistics: @statistics,
        output_directory: @output_directory
      }
    end
    
    # Быстрая миграция только тестовых данных
    def migrate_sample!(sample_size = 100)
      Rails.logger.info "🔄 Начинаем миграцию образца данных (#{sample_size} записей)"
      
      @sample_size = sample_size
      migrate!
    end
    
    private
    
    # Валидация входных файлов
    def validate_input_files
      required_files = %w[brand model kit kit_tyre_size]
      found_files = Dir.glob(File.join(@csv_directory, '*.csv')).map { |f| File.basename(f, '.csv') }
      
      missing_files = required_files.reject do |required|
        found_files.any? { |found| found.downcase.include?(required.downcase) }
      end
      
      if missing_files.any?
        raise "Отсутствуют необходимые CSV файлы: #{missing_files.join(', ')}"
      end
      
      Rails.logger.info "✅ Все необходимые CSV файлы найдены"
    end
    
    # Обработка CSV данных
    def process_csv_data
      Rails.logger.info "📁 Обрабатываем CSV файлы..."
      
      process_brands
      process_models
      process_kits_and_tire_sizes
      
      validate_processed_data
    end
    
    # Обработка брендов
    def process_brands
      brands_file = find_csv_file('brand')
      count = 0
      
      CSV.foreach(brands_file, headers: true, encoding: 'UTF-8') do |row|
        brand_id = row['id']&.to_i
        brand_name = row['name']&.strip
        
        next if brand_id.nil? || brand_name.blank?
        break if @sample_size && count >= @sample_size
        
        @processed_data[:brands][brand_id] = {
          id: brand_id,
          name: brand_name,
          name_normalized: normalize_name(brand_name),
          aliases: generate_brand_aliases(brand_name)
        }
        
        count += 1
      end
      
      @statistics[:brands_processed] = count
      Rails.logger.info "✅ Обработано брендов: #{count}"
    end
    
    # Обработка моделей
    def process_models
      models_file = find_csv_file('model')
      count = 0
      
      CSV.foreach(models_file, headers: true, encoding: 'UTF-8') do |row|
        model_id = row['id']&.to_i
        brand_id = row['brand_id']&.to_i
        model_name = row['name']&.strip
        
        next if model_id.nil? || brand_id.nil? || model_name.blank?
        next unless @processed_data[:brands][brand_id] # Пропускаем модели без бренда
        break if @sample_size && count >= @sample_size
        
        brand_name = @processed_data[:brands][brand_id][:name]
        
        @processed_data[:models][model_id] = {
          id: model_id,
          brand_id: brand_id,
          name: model_name,
          name_normalized: normalize_name(model_name),
          aliases: generate_model_aliases(brand_name, model_name)
        }
        
        count += 1
      end
      
      @statistics[:models_processed] = count
      Rails.logger.info "✅ Обработано моделей: #{count}"
    end
    
    # Обработка комплектаций и размеров шин
    def process_kits_and_tire_sizes
      kits_file = find_csv_file('kit')
      tire_sizes_file = find_csv_file('kit_tyre_size')
      
      # Загружаем комплектации
      kits = {}
      CSV.foreach(kits_file, headers: true, encoding: 'UTF-8') do |row|
        kit_id = row['id']&.to_i
        model_id = row['model_id']&.to_i
        year = row['year']&.to_i
        
        next if kit_id.nil? || model_id.nil? || year.nil?
        next unless @processed_data[:models][model_id]
        
        kits[kit_id] = {
          id: kit_id,
          model_id: model_id,
          year: year
        }
      end
      
      # Загружаем размеры шин и связываем с комплектациями
      tire_configurations = {}
      count = 0
      
      CSV.foreach(tire_sizes_file, headers: true, encoding: 'UTF-8') do |row|
        kit_id = row['kit_id']&.to_i
        width = row['width']&.to_i
        height = row['height']&.to_i
        diameter = row['diameter']&.to_i
        type = row['type']&.strip&.downcase || 'stock'
        
        next if kit_id.nil? || width.nil? || height.nil? || diameter.nil?
        next unless kits[kit_id]
        break if @sample_size && count >= @sample_size
        
        kit = kits[kit_id]
        model = @processed_data[:models][kit[:model_id]]
        next unless model
        
        brand = @processed_data[:brands][model[:brand_id]]
        next unless brand
        
        # Создаем ключ конфигурации: brand_id + model_id + year
        config_key = "#{brand[:id]}_#{model[:id]}_#{kit[:year]}"
        
        # Инициализируем конфигурацию
        unless tire_configurations[config_key]
          tire_configurations[config_key] = {
            brand_id: brand[:id],
            brand_name: brand[:name],
            model_id: model[:id], 
            model_name: model[:name],
            year: kit[:year],
            tire_sizes: []
          }
        end
        
        # Добавляем размер шин
        tire_size = {
          width: width,
          height: height,
          diameter: diameter,
          type: normalize_tire_type(type)
        }
        
        tire_configurations[config_key][:tire_sizes] << tire_size
        count += 1
      end
      
      @raw_configurations = tire_configurations.values
      @statistics[:raw_configurations] = @raw_configurations.size
      @statistics[:tire_sizes_processed] = count
      
      Rails.logger.info "✅ Обработано размеров шин: #{count}"
      Rails.logger.info "✅ Создано сырых конфигураций: #{@raw_configurations.size}"
    end
    
    # Валидация обработанных данных
    def validate_processed_data
      errors = []
      
      errors << "Не найдены бренды" if @processed_data[:brands].empty?
      errors << "Не найдены модели" if @processed_data[:models].empty?
      errors << "Не найдены конфигурации шин" if @raw_configurations.empty?
      
      if errors.any?
        raise "Ошибки валидации: #{errors.join(', ')}"
      end
      
      Rails.logger.info "✅ Валидация данных прошла успешно"
    end
    
    # Агрегация данных по диапазонам лет
    def aggregate_data
      Rails.logger.info "🔄 Агрегируем данные по диапазонам лет..."
      
      # Группируем по brand_id + model_id
      grouped = @raw_configurations.group_by { |config| [config[:brand_id], config[:model_id]] }
      
      grouped.each do |(brand_id, model_id), configs|
        brand = @processed_data[:brands][brand_id]
        model = @processed_data[:models][model_id]
        
        # Сортируем по годам
        sorted_configs = configs.sort_by { |c| c[:year] }
        
        # Создаем диапазоны лет
        ranges = create_year_ranges(sorted_configs)
        
        # Добавляем каждый диапазон как отдельную конфигурацию
        ranges.each do |range|
          @processed_data[:configurations] << {
            brand_id: brand_id,
            brand_name: brand[:name],
            brand_aliases: brand[:aliases],
            model_id: model_id,
            model_name: model[:name],
            model_aliases: model[:aliases],
            year_from: range[:year_from],
            year_to: range[:year_to],
            tire_sizes: range[:tire_sizes].uniq { |ts| [ts[:width], ts[:height], ts[:diameter]] },
            search_aliases: (brand[:aliases] + model[:aliases]).uniq,
            search_tokens: generate_search_tokens(brand, model)
          }
        end
      end
      
      @statistics[:final_configurations] = @processed_data[:configurations].size
      Rails.logger.info "✅ Создано финальных конфигураций: #{@processed_data[:configurations].size}"
    end
    
    # Создание диапазонов лет
    def create_year_ranges(configs)
      ranges = []
      current_range = nil
      
      configs.each do |config|
        if current_range.nil?
          current_range = {
            year_from: config[:year],
            year_to: config[:year],
            tire_sizes: config[:tire_sizes].dup
          }
        elsif config[:year] == current_range[:year_to] + 1
          # Расширяем диапазон
          current_range[:year_to] = config[:year]
          current_range[:tire_sizes].concat(config[:tire_sizes])
        else
          # Завершаем текущий диапазон
          ranges << current_range
          current_range = {
            year_from: config[:year],
            year_to: config[:year],
            tire_sizes: config[:tire_sizes].dup
          }
        end
      end
      
      ranges << current_range if current_range
      ranges
    end
    
    # Генерация seed файлов
    def generate_seed_files
      Rails.logger.info "📝 Генерируем seed файлы..."
      
      ensure_output_directory
      
      generate_brands_seed
      generate_models_seed
      generate_configurations_seed
      generate_aliases_seed
      
      Rails.logger.info "✅ Seed файлы созданы в #{@output_directory}"
    end
    
    # Создание папки для seed файлов
    def ensure_output_directory
      FileUtils.mkdir_p(@output_directory) unless Dir.exist?(@output_directory)
    end
    
    # Генерация seed файла брендов
    def generate_brands_seed
      file_path = File.join(@output_directory, 'tire_brands_processed.rb')
      
      File.open(file_path, 'w') do |file|
        file.puts "# Обработанные бренды автомобилей для системы поиска шин"
        file.puts "# Сгенерировано автоматически: #{Time.current}"
        file.puts "# Источник: #{@csv_directory}"
        file.puts ""
        file.puts "puts '=== Загрузка обработанных брендов автомобилей ==='"
        file.puts ""
        file.puts "processed_brands = ["
        
        @processed_data[:brands].values.each do |brand|
          file.puts "  {"
          file.puts "    name: #{brand[:name].inspect},"
          file.puts "    aliases: #{brand[:aliases].inspect},"
          file.puts "    is_active: true"
          file.puts "  },"
        end
        
        file.puts "]"
        file.puts ""
        file.puts "processed_brands.each do |brand_data|"
        file.puts "  brand = CarBrand.find_or_create_by(name: brand_data[:name]) do |b|"
        file.puts "    b.is_active = brand_data[:is_active]"
        file.puts "  end"
        file.puts "  puts \"✓ \#{brand.name}\""
        file.puts "end"
        file.puts ""
        file.puts "puts \"✅ Загружено брендов: \#{processed_brands.size}\""
      end
      
      @statistics[:brands_seed_generated] = true
    end
    
    # Генерация seed файла моделей
    def generate_models_seed
      file_path = File.join(@output_directory, 'tire_models_processed.rb')
      
      File.open(file_path, 'w') do |file|
        file.puts "# Обработанные модели автомобилей для системы поиска шин"
        file.puts "# Сгенерировано автоматически: #{Time.current}"
        file.puts "# Источник: #{@csv_directory}"
        file.puts ""
        file.puts "puts '=== Загрузка обработанных моделей автомобилей ==='"
        file.puts ""
        file.puts "processed_models = ["
        
        @processed_data[:models].values.each do |model|
          brand_name = @processed_data[:brands][model[:brand_id]][:name]
          file.puts "  {"
          file.puts "    brand_name: #{brand_name.inspect},"
          file.puts "    name: #{model[:name].inspect},"
          file.puts "    aliases: #{model[:aliases].inspect},"
          file.puts "    is_active: true"
          file.puts "  },"
        end
        
        file.puts "]"
        file.puts ""
        file.puts "processed_models.each do |model_data|"
        file.puts "  brand = CarBrand.find_by(name: model_data[:brand_name])"
        file.puts "  next unless brand"
        file.puts ""
        file.puts "  model = CarModel.find_or_create_by(brand: brand, name: model_data[:name]) do |m|"
        file.puts "    m.is_active = model_data[:is_active]"
        file.puts "  end"
        file.puts "  puts \"✓ \#{brand.name} \#{model.name}\""
        file.puts "end"
        file.puts ""
        file.puts "puts \"✅ Загружено моделей: \#{processed_models.size}\""
      end
      
      @statistics[:models_seed_generated] = true
    end
    
    # Генерация seed файла конфигураций
    def generate_configurations_seed
      file_path = File.join(@output_directory, 'tire_configurations_full.rb')
      
      File.open(file_path, 'w') do |file|
        file.puts "# Полные конфигурации шин для системы поиска"
        file.puts "# Сгенерировано автоматически: #{Time.current}"
        file.puts "# Источник: #{@csv_directory}"
        file.puts ""
        file.puts "puts '=== Загрузка конфигураций шин ==='"
        file.puts ""
        file.puts "configurations = ["
        
        @processed_data[:configurations].each do |config|
          file.puts "  {"
          file.puts "    brand_name: #{config[:brand_name].inspect},"
          file.puts "    model_name: #{config[:model_name].inspect},"
          file.puts "    year_from: #{config[:year_from]},"
          file.puts "    year_to: #{config[:year_to]},"
          file.puts "    tire_sizes: #{config[:tire_sizes].inspect},"
          file.puts "    search_aliases: #{config[:search_aliases].inspect},"
          file.puts "    search_tokens: #{config[:search_tokens].inspect}"
          file.puts "  },"
        end
        
        file.puts "]"
        file.puts ""
        file.puts "current_version = TireDataVersion.current&.version || '2025.1'"
        file.puts "created_count = 0"
        file.puts ""
        file.puts "configurations.each do |config_data|"
        file.puts "  brand = CarBrand.find_by(name: config_data[:brand_name])"
        file.puts "  model = CarModel.find_by(brand: brand, name: config_data[:model_name]) if brand"
        file.puts "  next unless brand && model"
        file.puts ""
        file.puts "  config = CarTireConfiguration.create!("
        file.puts "    brand: brand,"
        file.puts "    model: model,"
        file.puts "    year_from: config_data[:year_from],"
        file.puts "    year_to: config_data[:year_to],"
        file.puts "    tire_sizes: config_data[:tire_sizes],"
        file.puts "    search_aliases: config_data[:search_aliases],"
        file.puts "    search_tokens: config_data[:search_tokens],"
        file.puts "    data_version: current_version,"
        file.puts "    source_file: 'seeds/tire_configurations_full.rb',"
        file.puts "    last_updated: Time.current,"
        file.puts "    is_active: true,"
        file.puts "    is_deprecated: false"
        file.puts "  )"
        file.puts ""
        file.puts "  created_count += 1"
        file.puts "  puts \"✓ \#{config.full_name} - \#{config.tire_sizes.size} размеров\" if created_count % 100 == 0"
        file.puts "end"
        file.puts ""
        file.puts "puts \"✅ Загружено конфигураций: \#{created_count}\""
      end
      
      @statistics[:configurations_seed_generated] = true
    end
    
    # Генерация seed файла алиасов
    def generate_aliases_seed
      file_path = File.join(@output_directory, 'tire_search_aliases.rb')
      
      # Собираем все уникальные алиасы
      brand_aliases = {}
      model_aliases = {}
      
      @processed_data[:brands].values.each do |brand|
        brand_aliases[brand[:name]] = brand[:aliases] if brand[:aliases].any?
      end
      
      @processed_data[:models].values.each do |model|
        brand_name = @processed_data[:brands][model[:brand_id]][:name]
        model_aliases[brand_name] ||= {}
        model_aliases[brand_name][model[:name]] = model[:aliases] if model[:aliases].any?
      end
      
      File.open(file_path, 'w') do |file|
        file.puts "# Алиасы для поиска шин"
        file.puts "# Сгенерировано автоматически: #{Time.current}"
        file.puts "# Источник: #{@csv_directory}"
        file.puts ""
        file.puts "puts '=== Загрузка алиасов для поиска ==='"
        file.puts ""
        file.puts "# Алиасы брендов"
        file.puts "BRAND_ALIASES = {"
        brand_aliases.each do |brand, aliases|
          file.puts "  #{brand.inspect} => #{aliases.inspect},"
        end
        file.puts "}"
        file.puts ""
        file.puts "# Алиасы моделей"
        file.puts "MODEL_ALIASES = {"
        model_aliases.each do |brand, models|
          file.puts "  #{brand.inspect} => {"
          models.each do |model, aliases|
            file.puts "    #{model.inspect} => #{aliases.inspect},"
          end
          file.puts "  },"
        end
        file.puts "}"
        file.puts ""
        file.puts "puts \"✅ Алиасы брендов: \#{BRAND_ALIASES.size}\""
        file.puts "puts \"✅ Алиасы моделей: \#{MODEL_ALIASES.values.map(&:size).sum}\""
      end
      
      @statistics[:aliases_seed_generated] = true
    end
    
    # Генерация статистики
    def generate_statistics
      @statistics.merge!(
        total_brands: @processed_data[:brands].size,
        total_models: @processed_data[:models].size,
        total_configurations: @processed_data[:configurations].size,
        average_tire_sizes_per_config: @processed_data[:configurations].sum { |c| c[:tire_sizes].size } / @processed_data[:configurations].size.to_f,
        year_range: {
          min: @processed_data[:configurations].map { |c| c[:year_from] }.min,
          max: @processed_data[:configurations].map { |c| c[:year_to] }.max
        }
      )
    end
    
    # Вспомогательные методы
    
    def find_csv_file(pattern)
      files = Dir.glob(File.join(@csv_directory, '*.csv'))
      file = files.find { |f| File.basename(f).downcase.include?(pattern.downcase) }
      
      raise "CSV файл с паттерном '#{pattern}' не найден" unless file
      
      file
    end
    
    def normalize_name(name)
      name.strip.gsub(/[^\w\s-]/i, '').squeeze(' ')
    end
    
    def normalize_tire_type(type)
      case type&.downcase
      when 'stock', 'standard', 'штатный'
        'stock'
      when 'optional', 'option', 'опциональный'
        'optional'
      else
        'stock'
      end
    end
    
    def generate_brand_aliases(brand_name)
      # Используем существующие алиасы из TireSearchService
      aliases = []
      
      TireSearchService::BRAND_ALIASES.each do |alias_list, canonical_name|
        if canonical_name.downcase == brand_name.downcase || alias_list.include?(brand_name.downcase)
          aliases.concat(alias_list)
          break
        end
      end
      
      aliases.uniq
    end
    
    def generate_model_aliases(brand_name, model_name)
      aliases = []
      
      # Находим канонический бренд
      canonical_brand = nil
      TireSearchService::BRAND_ALIASES.each do |alias_list, brand|
        if brand.downcase == brand_name.downcase || alias_list.include?(brand_name.downcase)
          canonical_brand = brand
          break
        end
      end
      
      # Ищем алиасы модели
      if canonical_brand && TireSearchService::MODEL_ALIASES[canonical_brand]
        TireSearchService::MODEL_ALIASES[canonical_brand].each do |alias_list, canonical_model|
          if canonical_model.downcase == model_name.downcase || alias_list.include?(model_name.downcase)
            aliases.concat(alias_list)
            break
          end
        end
      end
      
      aliases.uniq
    end
    
    def generate_search_tokens(brand, model)
      tokens = [
        brand[:name].downcase,
        model[:name].downcase,
        brand[:aliases].join(' ').downcase,
        model[:aliases].join(' ').downcase
      ].join(' ')
      
      tokens.gsub(/[^\w\s]/i, ' ').squeeze(' ').strip
    end
  end
end