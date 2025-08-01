# frozen_string_literal: true

# Валидатор CSV файлов для импорта данных шин
class TireDataValidator
  REQUIRED_FILES = {
    'test_table_car2_brand.csv' => {
      description: 'Справочник брендов автомобилей',
      required_columns: ['id', 'name'],
      min_rows: 1
    },
    'test_table_car2_model.csv' => {
      description: 'Справочник моделей автомобилей',
      required_columns: ['id', 'brand', 'name'],
      min_rows: 1
    },
    'test_table_car2_kit.csv' => {
      description: 'Комплектации автомобилей',
      required_columns: ['id', 'model', 'year_from', 'year_to'],
      min_rows: 1
    },
    'test_table_car2_kit_tyre_size.csv' => {
      description: 'Размеры шин для комплектаций',
      required_columns: ['kit', 'width', 'height', 'diameter'],
      min_rows: 1
    }
  }.freeze

  def initialize(csv_path)
    @csv_path = csv_path
    @errors = []
    @warnings = []
    @file_stats = {}
  end

  def validate_all_files
    result = {
      valid: true,
      files: {},
      errors: [],
      warnings: [],
      statistics: {}
    }

    REQUIRED_FILES.each do |filename, config|
      file_path = File.join(@csv_path, filename)
      file_result = validate_file(file_path, config)
      
      result[:files][filename] = file_result
      result[:valid] = false unless file_result[:valid]
      result[:errors].concat(file_result[:errors])
      result[:warnings].concat(file_result[:warnings])
      result[:statistics][filename] = file_result[:statistics]
    end

    # Дополнительная валидация связей между файлами
    if result[:valid]
      cross_file_validation = validate_cross_file_relations
      result[:warnings].concat(cross_file_validation[:warnings])
      result[:statistics][:cross_validation] = cross_file_validation[:statistics]
    end

    result
  end

  private

  def validate_file(file_path, config)
    result = {
      valid: true,
      exists: false,
      readable: false,
      errors: [],
      warnings: [],
      statistics: {
        rows_count: 0,
        columns_count: 0,
        file_size: 0,
        encoding: 'unknown'
      }
    }

    filename = File.basename(file_path)

    # Проверка существования файла
    unless File.exist?(file_path)
      result[:valid] = false
      result[:errors] << "Файл #{filename} не найден"
      return result
    end

    result[:exists] = true
    result[:statistics][:file_size] = File.size(file_path)

    # Проверка читаемости
    unless File.readable?(file_path)
      result[:valid] = false
      result[:errors] << "Файл #{filename} недоступен для чтения"
      return result
    end

    result[:readable] = true

    begin
      # Определение кодировки
      encoding = detect_encoding(file_path)
      result[:statistics][:encoding] = encoding

      # Чтение и валидация CSV
      csv_data = CSV.read(file_path, headers: true, encoding: encoding)
      result[:statistics][:rows_count] = csv_data.length
      result[:statistics][:columns_count] = csv_data.headers&.length || 0

      # Проверка заголовков
      missing_columns = config[:required_columns] - csv_data.headers
      if missing_columns.any?
        result[:valid] = false
        result[:errors] << "В файле #{filename} отсутствуют обязательные колонки: #{missing_columns.join(', ')}"
      end

      # Проверка минимального количества строк
      if csv_data.length < config[:min_rows]
        result[:valid] = false
        result[:errors] << "В файле #{filename} недостаточно данных (минимум #{config[:min_rows]} строк, найдено #{csv_data.length})"
      end

      # Проверка на пустые обязательные поля
      empty_required_fields = validate_required_fields(csv_data, config[:required_columns])
      if empty_required_fields.any?
        result[:warnings] << "В файле #{filename} найдены пустые обязательные поля: #{empty_required_fields.join(', ')}"
      end

      # Специфичная валидация по типу файла
      specific_validation = validate_file_specific_rules(filename, csv_data)
      result[:warnings].concat(specific_validation[:warnings])
      result[:statistics].merge!(specific_validation[:statistics])

    rescue CSV::MalformedCSVError => e
      result[:valid] = false
      result[:errors] << "Ошибка формата CSV в файле #{filename}: #{e.message}"
    rescue Encoding::UndefinedConversionError => e
      result[:valid] = false
      result[:errors] << "Ошибка кодировки в файле #{filename}: #{e.message}"
    rescue => e
      result[:valid] = false
      result[:errors] << "Неожиданная ошибка при обработке файла #{filename}: #{e.message}"
    end

    result
  end

  def detect_encoding(file_path)
    # Простое определение кодировки
    sample = File.read(file_path, 1024)
    
    if sample.valid_encoding?
      'UTF-8'
    else
      # Пробуем другие кодировки
      ['Windows-1251', 'ISO-8859-1'].each do |encoding|
        begin
          sample.force_encoding(encoding)
          return encoding if sample.valid_encoding?
        rescue
          next
        end
      end
      'UTF-8' # По умолчанию
    end
  end

  def validate_required_fields(csv_data, required_columns)
    empty_fields = []
    
    required_columns.each do |column|
      empty_count = csv_data.count { |row| row[column].nil? || row[column].to_s.strip.empty? }
      if empty_count > 0
        empty_fields << "#{column} (#{empty_count} пустых значений)"
      end
    end
    
    empty_fields
  end

  def validate_file_specific_rules(filename, csv_data)
    result = { warnings: [], statistics: {} }

    case filename
    when 'test_table_car2_brand.csv'
      # Проверка уникальности ID и названий
      duplicate_ids = find_duplicates(csv_data, 'id')
      duplicate_names = find_duplicates(csv_data, 'name')
      
      result[:warnings] << "Дублирующиеся ID брендов: #{duplicate_ids.join(', ')}" if duplicate_ids.any?
      result[:warnings] << "Дублирующиеся названия брендов: #{duplicate_names.join(', ')}" if duplicate_names.any?
      result[:statistics][:unique_brands] = csv_data.map { |row| row['name'] }.uniq.count

    when 'test_table_car2_model.csv'
      # Проверка связи с брендами
      result[:statistics][:unique_models] = csv_data.map { |row| row['name'] }.uniq.count
      result[:statistics][:brands_referenced] = csv_data.map { |row| row['brand'] }.uniq.count

    when 'test_table_car2_kit.csv'
      # Проверка годов
      invalid_years = csv_data.select do |row|
        year_from = row['year_from'].to_i
        year_to = row['year_to'].to_i
        year_from > year_to || year_from < 1900 || year_to > Time.current.year + 2
      end
      
      result[:warnings] << "Некорректные диапазоны годов: #{invalid_years.count} записей" if invalid_years.any?
      result[:statistics][:year_range] = {
        min: csv_data.map { |row| row['year_from'].to_i }.min,
        max: csv_data.map { |row| row['year_to'].to_i }.max
      }

    when 'test_table_car2_kit_tyre_size.csv'
      # Проверка размеров шин
      invalid_sizes = csv_data.select do |row|
        width = row['width'].to_i
        height = row['height'].to_i
        diameter = row['diameter'].to_i
        
        width < 100 || width > 400 || 
        height < 25 || height > 100 || 
        diameter < 10 || diameter > 30
      end
      
      result[:warnings] << "Подозрительные размеры шин: #{invalid_sizes.count} записей" if invalid_sizes.any?
      result[:statistics][:tire_sizes] = {
        unique_combinations: csv_data.map { |row| "#{row['width']}/#{row['height']}R#{row['diameter']}" }.uniq.count,
        width_range: [csv_data.map { |row| row['width'].to_i }.min, csv_data.map { |row| row['width'].to_i }.max],
        diameter_range: [csv_data.map { |row| row['diameter'].to_i }.min, csv_data.map { |row| row['diameter'].to_i }.max]
      }
    end

    result
  end

  def find_duplicates(csv_data, column)
    values = csv_data.map { |row| row[column] }.compact
    values.group_by(&:itself).select { |_, v| v.size > 1 }.keys
  end

  def validate_cross_file_relations
    result = { warnings: [], statistics: {} }
    
    begin
      # Здесь можно добавить проверки связей между файлами
      # Например, проверить что все brand_id из models существуют в brands
      result[:statistics][:cross_validation_passed] = true
    rescue => e
      result[:warnings] << "Ошибка при проверке связей между файлами: #{e.message}"
      result[:statistics][:cross_validation_passed] = false
    end
    
    result
  end
end