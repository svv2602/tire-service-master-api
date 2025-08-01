require 'csv'
require 'digest'

module TireData
  class Processor
    attr_reader :csv_directory, :version, :statistics, :file_checksums
    
    def initialize(csv_directory, version = nil, options = {})
      @csv_directory = csv_directory
      @version = version || generate_version
      @options = options || {}
      @statistics = {}
      @file_checksums = {}
      @errors = []
      @skipped_rows = 0
    end
    
    # Основной метод обработки и обновления данных
    def process_and_update
      Rails.logger.info "🔄 Начинаем обработку данных шин из #{@csv_directory}"
      
      # Проверяем окружение
      return skip_in_test_environment if Rails.env.test?
      
      # Проверяем существование папки
      unless Dir.exist?(@csv_directory)
        raise "Папка с CSV файлами не найдена: #{@csv_directory}"
      end
      
      # Проверяем, нужно ли обновление
      return skip_if_no_changes if should_skip_update?
      
      # Создаем резервную копию
      backup_current_data
      
      begin
        # Обрабатываем CSV файлы
        process_csv_files
        
        # Создаем агрегированные данные
        create_aggregated_configurations
        
        # Автоматическая очистка проблемных моделей
        clean_brand_name_models
        
        # Сохраняем информацию о версии
        save_version_info
        
        # Очищаем старые данные
        cleanup_old_versions
        
        Rails.logger.info "✅ Обработка данных завершена успешно. Версия: #{@version}"
        
        {
          success: true,
          version: @version,
          statistics: @statistics,
          skipped_rows: @skipped_rows,
          warnings: @skipped_rows > 0 ? ["Пропущено поврежденных строк: #{@skipped_rows}"] : [],
          message: "Данные успешно обновлены до версии #{@version}"
        }
        
      rescue => e
        Rails.logger.error "❌ Ошибка при обработке данных: #{e.message}"
        rollback_on_error
        raise e
      end
    end
    
    # Проверка необходимости обновления по чексуммам файлов
    def should_skip_update?
      return false unless current_version_exists?
      
      current_checksums = calculate_file_checksums
      last_version = TireDataVersion.current
      
      if last_version&.file_checksums == current_checksums
        Rails.logger.info "⏭️ Файлы не изменились, обновление не требуется"
        return true
      end
      
      @file_checksums = current_checksums
      false
    end
    
    private
    
    # Генерация версии на основе текущей даты
    def generate_version
      now = Time.current
      "#{now.year}.#{now.month}"
    end
    
    # Пропуск в тестовом окружении
    def skip_in_test_environment
      Rails.logger.info "⏭️ Пропускаем обработку в тестовом окружении"
      { success: true, skipped: true, reason: 'test_environment' }
    end
    
    # Пропуск если нет изменений
    def skip_if_no_changes
      { success: true, skipped: true, reason: 'no_changes', version: @version }
    end
    
    # Проверка существования текущей версии
    def current_version_exists?
      TireDataVersion.current.present?
    end
    
    # Расчет чексумм файлов
    def calculate_file_checksums
      checksums = {}
      csv_files.each do |file_path|
        checksums[File.basename(file_path)] = Digest::MD5.file(file_path).hexdigest
      end
      checksums
    end
    
    # Получение списка CSV файлов
    def csv_files
      @csv_files ||= Dir.glob(File.join(@csv_directory, '*.csv')).sort.reject do |file|
        # Исключаем файл с размерами дисков - не нужен для размеров шин
        File.basename(file).include?('kit_disk_size')
      end
    end
    
    # Создание резервной копии текущих данных
    def backup_current_data
      return unless current_version_exists?
      
      Rails.logger.info "💾 Создаем резервную копию текущих данных"
      
      current_version = TireDataVersion.current
      current_version.update!(is_active: false) if current_version
      
      @statistics[:backup_created] = true
      @statistics[:backup_version] = current_version&.version
    end
    
    # Обработка CSV файлов
    def process_csv_files
      Rails.logger.info "📁 Обрабатываем CSV файлы..."
      
      @raw_data = {
        brands: {},
        models: {},
        kits: {},
        tire_sizes: {}
      }
      
      # Обрабатываем файлы в правильном порядке зависимостей
      # 1. Сначала бренды
      brand_files = csv_files.select { |f| File.basename(f) =~ /brand/i }
      brand_files.each do |file_path|
        Rails.logger.info "📄 Обрабатываем файл: #{File.basename(file_path)}"
        process_brands_file(file_path)
      end
      
      # 2. Затем модели (зависят от брендов)
      model_files = csv_files.select { |f| File.basename(f) =~ /model/i }
      model_files.each do |file_path|
        Rails.logger.info "📄 Обрабатываем файл: #{File.basename(file_path)}"
        process_models_file(file_path)
      end
      
      # 3. Затем комплектации (зависят от моделей)
      kit_files = csv_files.select { |f| File.basename(f) =~ /kit(?!.*tyre)/i }
      kit_files.each do |file_path|
        Rails.logger.info "📄 Обрабатываем файл: #{File.basename(file_path)}"
        process_kits_file(file_path)
      end
      
      # 4. Наконец размеры шин (зависят от комплектаций)
      tire_size_files = csv_files.select { |f| File.basename(f) =~ /kit.*tyre|tyre.*size/i }
      tire_size_files.each do |file_path|
        Rails.logger.info "📄 Обрабатываем файл: #{File.basename(file_path)}"
        process_tire_sizes_file(file_path)
      end
      
      validate_raw_data
    end
    
    # Обработка файла брендов
    def process_brands_file(file_path)
      count = 0
      safe_csv_foreach(file_path) do |row|
        brand_id = row['id']&.to_i
        brand_name = row['name']&.strip
        
        next if brand_id.nil? || brand_name.blank?
        
        @raw_data[:brands][brand_id] = {
          id: brand_id,
          name: brand_name,
          name_clean: clean_brand_name(brand_name)
        }
        count += 1
      end
      
      @statistics[:brands_processed] = count
      Rails.logger.info "✅ Обработано брендов: #{count}"
    end
    
    # Обработка файла моделей
    def process_models_file(file_path)
      count = 0
      safe_csv_foreach(file_path) do |row|
        model_id = row['id']&.to_i
        brand_id = row['brand']&.to_i  # Исправлено: в CSV колонка называется 'brand', а не 'brand_id'
        model_name = row['name']&.strip
        
        next if model_id.nil? || brand_id.nil? || model_name.blank?
        next unless @raw_data[:brands][brand_id] # Пропускаем модели без бренда
        
        @raw_data[:models][model_id] = {
          id: model_id,
          brand_id: brand_id,
          name: model_name,
          name_clean: clean_model_name(model_name)
        }
        count += 1
      end
      
      @statistics[:models_processed] = count
      Rails.logger.info "✅ Обработано моделей: #{count} (всего брендов: #{@raw_data[:brands].size})"
    end
    
    # Обработка файла комплектаций
    def process_kits_file(file_path)
      count = 0
      safe_csv_foreach(file_path) do |row|
        kit_id = row['id']&.to_i
        model_id = row['model']&.to_i  # Исправлено: в CSV колонка называется 'model', а не 'model_id'
        year = row['year']&.to_i
        kit_name = row['name']&.strip
        
        next if kit_id.nil? || model_id.nil? || year.nil?
        next unless @raw_data[:models][model_id] # Пропускаем комплектации без модели
        
        @raw_data[:kits][kit_id] = {
          id: kit_id,
          model_id: model_id,
          year: year,
          name: kit_name || "Standard"
        }
        count += 1
      end
      
      @statistics[:kits_processed] = count
      Rails.logger.info "✅ Обработано комплектаций: #{count} (всего моделей: #{@raw_data[:models].size})"
    end
    
    # Обработка файла размеров шин
    def process_tire_sizes_file(file_path)
      count = 0
      safe_csv_foreach(file_path) do |row|
        tire_id = row['id']&.to_i
        kit_id = row['kit']&.to_i  # Исправлено: в CSV колонка называется 'kit', а не 'kit_id'
        width = row['width']&.to_f&.to_i  # Конвертируем float в int
        height = row['height']&.to_f&.to_i  # Конвертируем float в int  
        diameter = row['diameter']&.to_f&.to_i  # Конвертируем float в int
        type = row['type']&.strip&.downcase || 'stock'
        axle = row['axle']&.strip&.downcase
        
        next if tire_id.nil? || kit_id.nil? || width.nil? || height.nil? || diameter.nil?
        next unless @raw_data[:kits][kit_id] # Пропускаем размеры без комплектации
        
        # Применяем автоматическое исправление размеров если включено
        if @options[:fix_suspicious_sizes]
          width, height, diameter = auto_fix_tire_size(width, height, diameter)
        end
        
        # Нормализуем тип
        normalized_type = normalize_tire_type(type)
        
        @raw_data[:tire_sizes][tire_id] = {
          id: tire_id,
          kit_id: kit_id,
          width: width,
          height: height,
          diameter: diameter,
          type: normalized_type,
          axle: axle
        }
        count += 1
      end
      
      @statistics[:tire_sizes_processed] = count
      Rails.logger.info "✅ Обработано размеров шин: #{count} (всего комплектаций: #{@raw_data[:kits].size})"
    end
    
    # Валидация обработанных данных
    def validate_raw_data
      errors = []
      
      errors << "Не найдены бренды" if @raw_data[:brands].empty?
      errors << "Не найдены модели" if @raw_data[:models].empty?
      errors << "Не найдены размеры шин" if @raw_data[:tire_sizes].empty?
      
      if errors.any?
        raise "Ошибки валидации данных: #{errors.join(', ')}"
      end
      
      Rails.logger.info "✅ Валидация сырых данных прошла успешно"
    end
    
    # Создание агрегированных конфигураций
    def create_aggregated_configurations
      Rails.logger.info "🔄 Создаем агрегированные конфигурации шин..."
      
      # Группируем данные по Brand -> Model -> Years
      configurations = {}
      
      @raw_data[:tire_sizes].each do |tire_id, tire_data|
        kit = @raw_data[:kits][tire_data[:kit_id]]
        next unless kit
        
        model = @raw_data[:models][kit[:model_id]]
        next unless model
        
        brand = @raw_data[:brands][model[:brand_id]]
        next unless brand
        
        # Создаем ключ конфигурации
        config_key = "#{brand[:id]}_#{model[:id]}_#{kit[:year]}"
        
        # Инициализируем конфигурацию если её нет
        unless configurations[config_key]
          configurations[config_key] = {
            brand_id: brand[:id],
            brand_name: brand[:name],
            model_id: model[:id],
            model_name: model[:name],
            year: kit[:year],
            tire_sizes: [],
            search_aliases: generate_search_aliases(brand[:name], model[:name])
          }
        end
        
        # Добавляем размер шин
        tire_size = {
          width: tire_data[:width],
          height: tire_data[:height],
          diameter: tire_data[:diameter],
          type: tire_data[:type]
        }
        
        configurations[config_key][:tire_sizes] << tire_size
      end
      
      # Агрегируем по диапазонам лет
      aggregated = aggregate_by_year_ranges(configurations)
      
      # Сохраняем в базу данных
      save_configurations(aggregated)
      
      @statistics[:configurations_created] = aggregated.size
      Rails.logger.info "✅ Создано конфигураций: #{aggregated.size}"
    end
    
    # Агрегация по диапазонам лет
    def aggregate_by_year_ranges(configurations)
      # Группируем по brand_id + model_id
      grouped = configurations.values.group_by { |config| [config[:brand_id], config[:model_id]] }
      
      aggregated = []
      
      grouped.each do |(brand_id, model_id), configs|
        # Сортируем по годам
        sorted_configs = configs.sort_by { |c| c[:year] }
        
        # Объединяем соседние годы в диапазоны
        ranges = []
        current_range = nil
        
        sorted_configs.each do |config|
          if current_range.nil?
            current_range = {
              brand_id: brand_id,
              model_id: model_id,
              brand_name: config[:brand_name],
              model_name: config[:model_name],
              year_from: config[:year],
              year_to: config[:year],
              tire_sizes: config[:tire_sizes].dup,
              search_aliases: config[:search_aliases]
            }
          elsif config[:year] == current_range[:year_to] + 1
            # Расширяем диапазон
            current_range[:year_to] = config[:year]
            # Объединяем размеры шин
            current_range[:tire_sizes] = merge_tire_sizes(current_range[:tire_sizes], config[:tire_sizes])
          else
            # Завершаем текущий диапазон и начинаем новый
            ranges << current_range
            current_range = {
              brand_id: brand_id,
              model_id: model_id,
              brand_name: config[:brand_name],
              model_name: config[:model_name],
              year_from: config[:year],
              year_to: config[:year],
              tire_sizes: config[:tire_sizes].dup,
              search_aliases: config[:search_aliases]
            }
          end
        end
        
        ranges << current_range if current_range
        aggregated.concat(ranges)
      end
      
      aggregated
    end
    
    # Объединение размеров шин
    def merge_tire_sizes(sizes1, sizes2)
      combined = (sizes1 + sizes2).uniq { |size| [size[:width], size[:height], size[:diameter]] }
      combined.sort_by { |size| [size[:diameter], size[:width], size[:height]] }
    end
    
    # Сохранение конфигураций в базу данных
    def save_configurations(configurations)
      Rails.logger.info "💾 Сохраняем конфигурации в базу данных..."
      
      # Находим или создаем бренды и модели в базе
      brand_mapping = create_brand_mapping
      model_mapping = create_model_mapping(brand_mapping)
      
      saved_count = 0
      
      configurations.each do |config|
        db_brand_id = brand_mapping[config[:brand_id]]
        db_model_id = model_mapping[config[:model_id]]
        
        next unless db_brand_id && db_model_id
        
        # Создаем поисковые токены
        search_tokens = generate_search_tokens(config[:brand_name], config[:model_name], config[:search_aliases])
        
        tire_config = CarTireConfiguration.create!(
          brand_id: db_brand_id,
          model_id: db_model_id,
          year_from: config[:year_from],
          year_to: config[:year_to],
          tire_sizes: config[:tire_sizes],
          search_aliases: config[:search_aliases],
          search_tokens: search_tokens,
          data_version: @version,
          source_file: @csv_directory,
          last_updated: Time.current,
          is_active: true,
          is_deprecated: false
        )
        
        saved_count += 1
      end
      
      @statistics[:configurations_saved] = saved_count
      Rails.logger.info "✅ Сохранено конфигураций в БД: #{saved_count}"
    end
    
    # Создание маппинга брендов
    def create_brand_mapping
      mapping = {}
      
      @raw_data[:brands].each do |csv_brand_id, brand_data|
        # Ищем существующий бренд или создаем новый
        db_brand = CarBrand.find_or_create_by(name: brand_data[:name_clean]) do |brand|
          brand.is_active = true
        end
        
        mapping[csv_brand_id] = db_brand.id
      end
      
      mapping
    end
    
    # Создание маппинга моделей
    def create_model_mapping(brand_mapping)
      mapping = {}
      
      @raw_data[:models].each do |csv_model_id, model_data|
        db_brand_id = brand_mapping[model_data[:brand_id]]
        next unless db_brand_id
        
        # Ищем существующую модель или создаем новую
        db_model = CarModel.find_or_create_by(
          brand_id: db_brand_id,
          name: model_data[:name_clean]
        ) do |model|
          model.is_active = true
        end
        
        mapping[csv_model_id] = db_model.id
      end
      
      mapping
    end
    
    # Сохранение информации о версии
    def save_version_info
      Rails.logger.info "📋 Сохраняем информацию о версии #{@version}"
      
      TireDataVersion.create!(
        version: @version,
        source_description: "Автоматическая обработка CSV файлов из #{@csv_directory}",
        file_checksums: @file_checksums,
        statistics: @statistics,
        imported_at: Time.current,
        is_active: true
      )
    end
    
    # Очистка старых версий
    def cleanup_old_versions
      TireDataVersion.cleanup_old_versions!(5) # Оставляем последние 5 версий
    end
    
    # Откат при ошибке
    def rollback_on_error
      Rails.logger.info "🔄 Выполняем откат изменений..."
      
      # Удаляем созданные в этой версии конфигурации
      CarTireConfiguration.where(data_version: @version).delete_all
      
      # Восстанавливаем предыдущую версию
      if @statistics[:backup_version]
        backup_version = TireDataVersion.find_by(version: @statistics[:backup_version])
        backup_version&.activate!
      end
    end
    
    # Вспомогательные методы для очистки имен
    
    def clean_brand_name(name)
      name.strip.gsub(/[^\w\s-]/i, '').squeeze(' ')
    end
    
    def clean_model_name(name)
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
    
    def generate_search_aliases(brand_name, model_name)
      aliases = []
      
      # Добавляем стандартные алиасы для популярных брендов
      brand_aliases = TireSearchService::BRAND_ALIASES.find { |aliases_list, _| aliases_list.include?(brand_name.downcase) }
      aliases.concat(brand_aliases[0]) if brand_aliases
      
      # Добавляем алиасы для моделей
      if brand_aliases
        canonical_brand = brand_aliases[1]
        model_aliases = TireSearchService::MODEL_ALIASES[canonical_brand]
        if model_aliases
          model_alias = model_aliases.find { |aliases_list, _| aliases_list.include?(model_name.downcase) }
          aliases.concat(model_alias[0]) if model_alias
        end
      end
      
      aliases.uniq
    end
    
    def generate_search_tokens(brand_name, model_name, aliases)
      tokens = [
        brand_name.downcase,
        model_name.downcase,
        aliases&.join(' ')&.downcase
      ].compact.join(' ')
      
      tokens.gsub(/[^\w\s]/i, ' ').squeeze(' ').strip
    end

    # Безопасное чтение CSV с обработкой ошибок
        def safe_csv_foreach(file_path, &block)
      line_number = 0

      # Пробуем различные варианты парсинга CSV
      csv_options = [
        { headers: true, encoding: 'UTF-8' },
        { headers: true, encoding: 'UTF-8', liberal_parsing: true },
        { headers: true, encoding: 'UTF-8', quote_char: '"', liberal_parsing: true },
        { headers: true, encoding: 'Windows-1251' },
        { headers: true, encoding: 'Windows-1251', liberal_parsing: true }
      ]

      csv_options.each_with_index do |options, attempt|
        begin
          Rails.logger.info "🔄 Попытка #{attempt + 1}/#{csv_options.length} для #{File.basename(file_path)} с опциями: #{options.inspect}"
          line_number = 0
          processed_rows = 0
          
          CSV.foreach(file_path, **options) do |row|
            line_number += 1
            processed_rows += 1
            yield row
          end
          
          Rails.logger.info "✅ Успешно обработано #{processed_rows} строк из #{File.basename(file_path)}"
          return # Успешно обработали файл
          
        rescue CSV::MalformedCSVError => e
          Rails.logger.warn "⚠️ Попытка #{attempt + 1} не удалась для #{File.basename(file_path)}: #{e.message}"
          
          if attempt < csv_options.length - 1
            next # Пробуем следующий вариант
          end
          
          # Последняя попытка не удалась
          if @options[:skip_invalid_rows]
            Rails.logger.warn "⚠️ Все попытки стандартного парсинга не удались. Используем построчное чтение для #{File.basename(file_path)}"
            retry_csv_reading(file_path, 1, &block)
            return
          else
            Rails.logger.error "❌ Все попытки парсинга не удались: #{e.message}"
            raise e
          end
          
        rescue ArgumentError => e
          Rails.logger.warn "⚠️ Ошибка кодировки в попытке #{attempt + 1}: #{e.message}"
          
          if attempt < csv_options.length - 1
            next
          end
          
          # Последняя попытка с кодировкой не удалась
          if @options[:skip_invalid_rows]
            Rails.logger.warn "⚠️ Ошибки кодировки. Используем построчное чтение для #{File.basename(file_path)}"
            retry_csv_reading(file_path, 1, &block)
            return
          else
            raise e
          end
          
        rescue => e
          Rails.logger.error "❌ Неожиданная ошибка в попытке #{attempt + 1}: #{e.class.name}: #{e.message}"
          
          if attempt < csv_options.length - 1
            next
          end
          
          # Последняя попытка - используем построчное чтение если включено
          if @options[:skip_invalid_rows]
            Rails.logger.warn "⚠️ Неожиданная ошибка. Используем построчное чтение для #{File.basename(file_path)}"
            retry_csv_reading(file_path, 1, &block)
            return
          else
            raise e
          end
        end
      end
      
      # Если мы дошли до этой точки, значит все попытки не удались, но исключений не было
      Rails.logger.warn "⚠️ Все попытки парсинга завершились без результата для #{File.basename(file_path)}"
      if @options[:skip_invalid_rows]
        Rails.logger.warn "⚠️ Используем построчное чтение как последнюю попытку для #{File.basename(file_path)}"
        retry_csv_reading(file_path, 1, &block)
      end
    end

    # Попытка продолжить чтение CSV с определенной строки
    def retry_csv_reading(file_path, start_line, &block)
      current_line = 0
      headers = nil
      successful_rows = 0
      
      File.foreach(file_path, encoding: 'UTF-8') do |line|
        current_line += 1
        
        if current_line == 1
          begin
            headers = CSV.parse_line(line, liberal_parsing: true)
          rescue CSV::MalformedCSVError
            headers = line.strip.split(',').map { |h| h.gsub(/["']/, '') }
          end
          next
        end
        
        next if current_line < start_line
        
        begin
          # Пробуем несколько способов парсинга строки
          parsed_line = nil
          
          [
            { liberal_parsing: true },
            { liberal_parsing: true, quote_char: '"' },
            { liberal_parsing: true, quote_char: "'" }
          ].each do |options|
            begin
              parsed_line = CSV.parse_line(line.strip, **options)
              break if parsed_line
            rescue CSV::MalformedCSVError
              next
            end
          end
          
          # Если обычный парсинг не сработал, пробуем простое разделение
          if !parsed_line
            parsed_line = line.strip.split(',').map { |cell| cell.gsub(/^["']|["']$/, '') }
          end
          
          if parsed_line && headers && parsed_line.length >= headers.length
            row = CSV::Row.new(headers, parsed_line[0...headers.length])
            yield row
            successful_rows += 1
          else
            Rails.logger.warn "⚠️ Пропущена строка #{current_line}: неверное количество колонок"
            @skipped_rows += 1
          end
        rescue => e
          Rails.logger.warn "⚠️ Пропущена строка #{current_line}: #{e.message}"
          @skipped_rows += 1
          next
        end
      end
      
      Rails.logger.info "✅ Построчное чтение завершено: обработано #{successful_rows} строк, пропущено #{@skipped_rows}"
    end

    # Автоисправление размеров шин
    def auto_fix_tire_size(width, height, diameter)
      fixed_width = width.to_f
      fixed_height = height.to_f
      fixed_diameter = diameter.to_f
      
      # 1. Исправление нулевой высоты профиля
      # Если высота 0, то подставляем 80 (стандартная высота)
      if fixed_height == 0.0
        fixed_height = 80.0  # 165/80R13, 175/80R14, и т.д.
      end
      
      # 2. Обработка американских дюймовых размеров
      # Размеры типа 28.0/9.0R15.0 - это американские дюймовые размеры
      # Оставляем как есть, только убираем лишние нули
      if fixed_width < 100 && fixed_width > 6
        # Это дюймовые размеры - не конвертируем, просто нормализуем
        # 28.0/9.0R15.0 → 28/9R15
        # Ничего не меняем, это валидные американские размеры
      elsif fixed_width < 6
        # Слишком маленькая ширина даже для дюймовых размеров
        fixed_width = 165.0  # минимальная метрическая ширина
      elsif fixed_width > 400
        fixed_width = 315.0  # максимальная стандартная ширина
      end
      
      # 3. Исправление диаметра
      if fixed_diameter < 10
        fixed_diameter = 13.0  # минимальный стандартный диаметр
      elsif fixed_diameter > 30
        fixed_diameter = 22.0  # максимальный стандартный диаметр
      end
      
      # 4. Исправление экстремальной высоты профиля
      if fixed_height > 100
        fixed_height = 80.0  # стандартная высота
      elsif fixed_height < 25 && fixed_height > 0
        fixed_height = 35.0  # минимальная стандартная высота
      end
      
      [fixed_width.to_i, fixed_height.to_i, fixed_diameter.to_i]
    end

    # Автоматическая очистка моделей с названиями брендов
    def clean_brand_name_models
      Rails.logger.info "🧹 Автоматическая очистка проблемных моделей..."
      
      # Получаем все названия брендов
      brand_names = CarBrand.pluck(:name).map(&:strip).uniq
      
      # Находим модели, которые совпадают с названиями брендов
      problematic_models = CarModel.joins(:brand).where(name: brand_names)
      
      return if problematic_models.count == 0
      
      Rails.logger.info "🔍 Найдено #{problematic_models.count} проблемных моделей"
      
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
      
      # Исключения - модели, которые могут совпадать с брендами но являются реальными моделями
      valid_coincidences = ['Jetta', 'ZX', 'Tank', 'Victory', 'Emgrand', 'Gratour']
      
      removed_count = 0
      
      problematic_models.includes(:brand).each do |model|
        brand_name = model.brand.name
        model_name = model.name
        
        # Проверяем, является ли модель явно проблемной
        is_problematic = false
        
        # Проверяем явные случаи дочерних брендов
        if problematic_cases[brand_name]&.include?(model_name)
          is_problematic = true
        # Проверяем совпадения с названиями брендов (исключая валидные)
        elsif brand_names.include?(model_name) && brand_name != model_name && !valid_coincidences.include?(model_name)
          is_problematic = true
        end
        
        if is_problematic
          Rails.logger.info "    Удаляем: #{brand_name} -> #{model_name}"
          model.destroy
          removed_count += 1
        end
      end
      
      if removed_count > 0
        Rails.logger.info "✅ Удалено #{removed_count} проблемных моделей"
        @statistics[:cleaned_models] = removed_count
      else
        Rails.logger.info "✅ Проблемных моделей не найдено"
      end
    end
  end
end