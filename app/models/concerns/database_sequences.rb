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
    def fix_table_sequence(table)
      max_id = ActiveRecord::Base.connection.execute(
        "SELECT MAX(id) FROM #{table}"
      ).first['max'] || 0
      
      sequence_name = "#{table}_id_seq"
      
      # Проверяем существование последовательности
      sequence_exists = ActiveRecord::Base.connection.execute(
        "SELECT 1 FROM pg_sequences WHERE sequencename = '#{sequence_name}'"
      ).ntuples > 0
      
      return { fixed: false, reason: 'sequence_not_found' } unless sequence_exists
      
      current_val = ActiveRecord::Base.connection.execute(
        "SELECT last_value FROM #{sequence_name}"
      ).first['last_value']
      
      if current_val <= max_id
        next_val = max_id + 1
        ActiveRecord::Base.connection.execute(
          "SELECT setval('#{sequence_name}', #{next_val})"
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
    def check_table_sequence(table)
      max_id = ActiveRecord::Base.connection.execute(
        "SELECT MAX(id) FROM #{table}"
      ).first['max'] || 0
      
      sequence_name = "#{table}_id_seq"
      
      sequence_exists = ActiveRecord::Base.connection.execute(
        "SELECT 1 FROM pg_sequences WHERE sequencename = '#{sequence_name}'"
      ).ntuples > 0
      
      return { table: table, has_problem: false, reason: 'no_sequence' } unless sequence_exists
      
      current_val = ActiveRecord::Base.connection.execute(
        "SELECT last_value FROM #{sequence_name}"
      ).first['last_value']
      
      record_count = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) FROM #{table}"
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