require 'csv'
require 'digest'

module TireData
  class Processor
    attr_reader :csv_directory, :version, :statistics, :file_checksums
    
    def initialize(csv_directory, version = nil)
      @csv_directory = csv_directory
      @version = version || generate_version
      @statistics = {}
      @file_checksums = {}
      @errors = []
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
        
        # Сохраняем информацию о версии
        save_version_info
        
        # Очищаем старые данные
        cleanup_old_versions
        
        Rails.logger.info "✅ Обработка данных завершена успешно. Версия: #{@version}"
        
        {
          success: true,
          version: @version,
          statistics: @statistics,
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
      @csv_files ||= Dir.glob(File.join(@csv_directory, '*.csv')).sort
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
      
      csv_files.each do |file_path|
        filename = File.basename(file_path)
        Rails.logger.info "📄 Обрабатываем файл: #{filename}"
        
        case filename
        when /brand/i
          process_brands_file(file_path)
        when /model/i
          process_models_file(file_path)
        when /kit(?!.*tyre)/i # kit, но не kit_tyre
          process_kits_file(file_path)
        when /kit.*tyre|tyre.*size/i
          process_tire_sizes_file(file_path)
        else
          Rails.logger.warn "⚠️ Неизвестный тип файла: #{filename}"
        end
      end
      
      validate_raw_data
    end
    
    # Обработка файла брендов
    def process_brands_file(file_path)
      count = 0
      CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
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
      CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
        model_id = row['id']&.to_i
        brand_id = row['brand_id']&.to_i
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
      Rails.logger.info "✅ Обработано моделей: #{count}"
    end
    
    # Обработка файла комплектаций
    def process_kits_file(file_path)
      count = 0
      CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
        kit_id = row['id']&.to_i
        model_id = row['model_id']&.to_i
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
      Rails.logger.info "✅ Обработано комплектаций: #{count}"
    end
    
    # Обработка файла размеров шин
    def process_tire_sizes_file(file_path)
      count = 0
      CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
        tire_id = row['id']&.to_i
        kit_id = row['kit_id']&.to_i
        width = row['width']&.to_i
        height = row['height']&.to_i
        diameter = row['diameter']&.to_i
        type = row['type']&.strip&.downcase || 'stock'
        axle = row['axle']&.strip&.downcase
        
        next if tire_id.nil? || kit_id.nil? || width.nil? || height.nil? || diameter.nil?
        next unless @raw_data[:kits][kit_id] # Пропускаем размеры без комплектации
        
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
      Rails.logger.info "✅ Обработано размеров шин: #{count}"
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
  end
end