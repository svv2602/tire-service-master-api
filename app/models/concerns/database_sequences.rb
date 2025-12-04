# app/models/concerns/database_sequences.rb
# Класс для управления последовательностями PostgreSQL

class DatabaseSequences
  class << self
    # Проверка и исправление всех последовательностей
    def fix_all_sequences!
      return unless Rails.env.development? || Rails.env.production?
      return unless ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      
      tables = get_tables_with_sequences
      results = { fixed: 0, errors: 0, checked: 0 }
      
      tables.each do |table|
        begin
          result = fix_table_sequence(table)
          results[:fixed] += 1 if result[:fixed]
          results[:checked] += 1
        rescue => e
          Rails.logger.warn "Ошибка при исправлении последовательности #{table}: #{e.message}"
          results[:errors] += 1
        end
      end
      
      results
    end
    
    # Проверка состояния всех последовательностей
    def check_all_sequences
      return [] unless Rails.env.development? || Rails.env.production?
      return [] unless ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      
      tables = get_tables_with_sequences
      problems = []
      
      tables.each do |table|
        begin
          status = check_table_sequence(table)
          problems << status if status[:has_problem]
        rescue => e
          problems << { 
            table: table, 
            error: e.message, 
            has_problem: true 
          }
        end
      end
      
      problems
    end
    
    private
    
    # Получение списка таблиц с последовательностями
    def get_tables_with_sequences
      %w[
        regions cities users clients partners bookings service_points reviews
        car_types car_brands car_models service_categories amenities
        user_roles booking_statuses payment_statuses page_contents
      ].select do |table|
        ActiveRecord::Base.connection.table_exists?(table) &&
        ActiveRecord::Base.connection.column_exists?(table, :id)
      end
    end
    
    # Исправление последовательности для конкретной таблицы
    # Security: table names are validated against whitelist in get_tables_with_sequences
    def fix_table_sequence(table)
      conn = ActiveRecord::Base.connection
      quoted_table = conn.quote_table_name(table)
      sequence_name = "#{table}_id_seq"
      quoted_sequence = conn.quote_table_name(sequence_name)

      max_id = conn.execute(
        "SELECT MAX(id) FROM #{quoted_table}"
      ).first['max'] || 0

      # Проверяем существование последовательности (используем параметризованный запрос)
      sequence_exists = conn.select_value(
        "SELECT 1 FROM pg_sequences WHERE sequencename = $1", 'Check sequence', [[nil, sequence_name]]
      )

      return { fixed: false, reason: 'sequence_not_found' } unless sequence_exists

      current_val = conn.execute(
        "SELECT last_value FROM #{quoted_sequence}"
      ).first['last_value']

      if current_val <= max_id
        next_val = max_id + 1
        conn.execute(
          conn.sanitize_sql_array(["SELECT setval(?, ?)", sequence_name, next_val])
        )

        {
          fixed: true,
          table: table,
          old_value: current_val,
          new_value: next_val,
          max_id: max_id
        }
      else
        { fixed: false, reason: 'already_correct' }
      end
    end
    
    # Проверка последовательности для конкретной таблицы
    # Security: table names are validated against whitelist in get_tables_with_sequences
    def check_table_sequence(table)
      conn = ActiveRecord::Base.connection
      quoted_table = conn.quote_table_name(table)
      sequence_name = "#{table}_id_seq"
      quoted_sequence = conn.quote_table_name(sequence_name)

      max_id = conn.execute(
        "SELECT MAX(id) FROM #{quoted_table}"
      ).first['max'] || 0

      # Используем параметризованный запрос для проверки последовательности
      sequence_exists = conn.select_value(
        "SELECT 1 FROM pg_sequences WHERE sequencename = $1", 'Check sequence', [[nil, sequence_name]]
      )

      return { table: table, has_problem: false, reason: 'no_sequence' } unless sequence_exists

      current_val = conn.execute(
        "SELECT last_value FROM #{quoted_sequence}"
      ).first['last_value']

      record_count = conn.execute(
        "SELECT COUNT(*) FROM #{quoted_table}"
      ).first['count']

      has_problem = current_val <= max_id

      {
        table: table,
        has_problem: has_problem,
        current_sequence: current_val,
        max_id: max_id,
        record_count: record_count,
        sequence_name: sequence_name
      }
    end
  end
end 