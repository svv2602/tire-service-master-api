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
            conn = ActiveRecord::Base.connection

            # Проверяем существование таблицы
            next unless conn.table_exists?(table)
            next unless conn.column_exists?(table, :id)

            # Security: use quote_table_name to prevent SQL injection
            quoted_table = conn.quote_table_name(table)
            sequence_name = "#{table}_id_seq"
            quoted_sequence = conn.quote_table_name(sequence_name)

            # Получаем данные
            max_id = conn.execute(
              "SELECT MAX(id) FROM #{quoted_table}"
            ).first['max'] || 0

            # Проверяем существование последовательности (параметризованный запрос)
            sequence_exists = conn.select_value(
              "SELECT 1 FROM pg_sequences WHERE sequencename = $1", 'Check sequence', [[nil, sequence_name]]
            )

            next unless sequence_exists

            current_val = conn.execute(
              "SELECT last_value FROM #{quoted_sequence}"
            ).first['last_value']

            # Исправляем последовательность если нужно
            if current_val <= max_id
              next_val = max_id + 1
              conn.execute(
                conn.sanitize_sql_array(["SELECT setval(?, ?)", sequence_name, next_val])
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