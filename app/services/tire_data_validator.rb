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
      line_number = extract_line_number_from_csv_error(e.message)
      if line_number
        result[:errors] << "Ошибка формата CSV в файле #{filename}: Некорректные данные в строке #{line_number}. Возможно, незакрытые кавычки или лишние символы."
        result[:auto_fixable] = true
        result[:fix_suggestion] = "Можно пропустить поврежденные строки при импорте"
      else
        result[:errors] << "Ошибка формата CSV в файле #{filename}: #{translate_csv_error(e.message)}"
      end
    rescue Encoding::UndefinedConversionError => e
      result[:valid] = false
      result[:errors] << "Ошибка кодировки в файле #{filename}: Файл содержит символы, которые не могут быть преобразованы в UTF-8"
      result[:auto_fixable] = true
      result[:fix_suggestion] = "Можно попробовать другую кодировку или пропустить проблемные символы"
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
      problem_types = {
        zero_height: [],
        american_sizes: [],
        extreme_values: []
      }
      
      csv_data.each_with_index do |row, idx|
        width = row['width'].to_f
        height = row['height'].to_f
        diameter = row['diameter'].to_f
        
        # Нулевая высота профиля
        if height == 0.0
          problem_types[:zero_height] << idx + 2
        end
        
        # Американские дюймовые размеры
        if width < 100 && width > 6 && height > 0
          problem_types[:american_sizes] << idx + 2
        end
        
        # Экстремальные значения
        if width < 6 || width > 400 || height > 100 || diameter < 10 || diameter > 30
          problem_types[:extreme_values] << idx + 2
        end
      end
      
      total_problems = problem_types.values.flatten.uniq.count
      
      if total_problems > 0
        warning_parts = []
        warning_parts << "#{problem_types[:zero_height].count} записей с нулевой высотой (будет заменена на 80)" if problem_types[:zero_height].any?
        warning_parts << "#{problem_types[:american_sizes].count} американских дюймовых размеров (сохранятся как есть)" if problem_types[:american_sizes].any?
        warning_parts << "#{problem_types[:extreme_values].count} записей с экстремальными значениями" if problem_types[:extreme_values].any?
        
        result[:warnings] << "Найдены проблемы в размерах шин: #{warning_parts.join(', ')}"
        result[:auto_fixable] = true
        result[:fix_suggestion] = "Автоисправление: нулевая высота → 80%, американские размеры сохраняются, экстремальные значения нормализуются"
      end
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

  # Извлечение номера строки из ошибки CSV
  def extract_line_number_from_csv_error(error_message)
    # Ищем паттерны типа "line 3310" или "строка 3310"
    match = error_message.match(/line (\d+)/i) || error_message.match(/строка (\d+)/i)
    match ? match[1].to_i : nil
  end

  # Перевод ошибок CSV на русский язык
  def translate_csv_error(error_message)
    translations = {
      'Any value after quoted field isn\'t allowed' => 'Недопустимые символы после закрытия кавычек',
      'Unclosed quoted field' => 'Незакрытое поле в кавычках',
      'Illegal quoting' => 'Неправильное использование кавычек',
      'Invalid byte sequence' => 'Недопустимая последовательность байтов'
    }
    
    translations.each do |english, russian|
      return russian if error_message.include?(english)
    end
    
    error_message # Возвращаем оригинал, если перевод не найден
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
    
    [fixed_width, fixed_height, fixed_diameter]
  end
end