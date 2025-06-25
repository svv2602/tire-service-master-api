# config/initializers/database_sequences.rb
# Автоматическая проверка и исправление последовательностей PostgreSQL при запуске

Rails.application.configure do
  # Выполняем только в development и production окружениях
  # Пропускаем в test окружении для ускорения тестов
  if Rails.env.development? || Rails.env.production?
    
    # Выполняем после полной инициализации приложения
    config.after_initialize do
      # Проверяем, что база данных доступна
      begin
        # Проверяем подключение к базе данных
        ActiveRecord::Base.connection.execute("SELECT 1")
        
        # Выполняем проверку последовательностей
        Rails.logger.info "🔍 Проверка последовательностей PostgreSQL при запуске..."
        
        # Основные таблицы приложения
        tables = %w[
          regions cities users clients partners bookings service_points reviews
          car_types car_brands car_models service_categories amenities
          user_roles booking_statuses payment_statuses page_contents
        ]
        
        problems_found = 0
        fixed_count = 0
        
        tables.each do |table|
          begin
            # Проверяем существование таблицы
            next unless ActiveRecord::Base.connection.table_exists?(table)
            next unless ActiveRecord::Base.connection.column_exists?(table, :id)
            
            # Получаем данные
            max_id = ActiveRecord::Base.connection.execute(
              "SELECT MAX(id) FROM #{table}"
            ).first['max'] || 0
            
            sequence_name = "#{table}_id_seq"
            
            # Проверяем существование последовательности
            sequence_exists = ActiveRecord::Base.connection.execute(
              "SELECT 1 FROM pg_sequences WHERE sequencename = '#{sequence_name}'"
            ).ntuples > 0
            
            next unless sequence_exists
            
            current_val = ActiveRecord::Base.connection.execute(
              "SELECT last_value FROM #{sequence_name}"
            ).first['last_value']
            
            # Исправляем последовательность если нужно
            if current_val <= max_id
              next_val = max_id + 1
              ActiveRecord::Base.connection.execute(
                "SELECT setval('#{sequence_name}', #{next_val})"
              )
              
              Rails.logger.info "  ✅ #{table}: исправлена последовательность #{current_val} → #{next_val}"
              problems_found += 1
              fixed_count += 1
            end
            
          rescue => e
            Rails.logger.warn "  ❌ Ошибка при проверке #{table}: #{e.message}"
          end
        end
        
        if problems_found > 0
          Rails.logger.info "🎉 Исправлено последовательностей: #{fixed_count}"
        else
          Rails.logger.info "✅ Все последовательности PostgreSQL в порядке"
        end
        
      rescue => e
        # Если база данных недоступна или другая ошибка, просто логируем
        Rails.logger.warn "⚠️  Не удалось проверить последовательности: #{e.message}"
      end
    end
  end
end 