# db/seeds/00_database_reset.rb
# Полная очистка базы данных с корректным порядком удаления

class DatabaseReset
  def self.perform!
    puts "=== ПОЛНАЯ ОЧИСТКА БАЗЫ ДАННЫХ ==="
    puts "Начинаем процесс очистки..."

    # Отключаем внешние ключи для безопасного удаления
    disable_foreign_keys

    # Получаем все модели в правильном порядке для удаления
    models_to_clear = get_models_in_deletion_order

    # Очищаем все таблицы
    clear_all_tables(models_to_clear)

    # Сбрасываем последовательности
    reset_sequences(models_to_clear)

    # Включаем внешние ключи обратно
    enable_foreign_keys

    puts "✅ База данных полностью очищена!"
    puts "📊 Статистика после очистки:"
    print_database_stats
  end

  private

  def self.disable_foreign_keys
    case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL"
      puts "🔒 Отключение проверки внешних ключей (PostgreSQL)..."
      ActiveRecord::Base.connection.execute("SET session_replication_role = 'replica';")
    when "SQLite"
      puts "🔒 Отключение проверки внешних ключей (SQLite)..."
      ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF;")
    when "Mysql2"
      puts "🔒 Отключение проверки внешних ключей (MySQL)..."
      ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 0;")
    end
  end

  def self.enable_foreign_keys
    case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL"
      puts "🔓 Включение проверки внешних ключей (PostgreSQL)..."
      ActiveRecord::Base.connection.execute("SET session_replication_role = 'origin';")
    when "SQLite"
      puts "🔓 Включение проверки внешних ключей (SQLite)..."
      ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON;")
    when "Mysql2"
      puts "🔓 Включение проверки внешних ключей (MySQL)..."
      ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 1;")
    end
  end

  def self.get_models_in_deletion_order
    # Порядок удаления: сначала зависимые таблицы, потом основные
    [
      # Связующие таблицы и зависимые сущности
      'Booking',
      'ServicePointService',
      'ServicePointAmenity', 
      'ServicePointPhoto',
      'ServicePost',
      'ScheduleTemplate',
      'Review',
      'Article',
      'PageContent',
      'ClientCar',
      'PaymentStatus',
      'BookingStatus',
      
      # Основные сущности с внешними ключами
      'ServicePoint',
      'Service',
      'ServiceCategory',
      'Amenity',
      'Client',
      'Administrator',
      'Operator', 
      'Partner',
      'CarModel',
      'CarBrand',
      'CarType',
      
      # Географические данные
      'City',
      'Region',
      
      # Пользователи и роли (удаляем в последнюю очередь)
      'User',
      'UserRole'
    ].map { |model_name| 
      begin
        model_name.constantize
      rescue NameError
        puts "⚠️  Модель #{model_name} не найдена, пропускаем"
        nil
      end
    }.compact
  end

  def self.clear_all_tables(models)
    puts "\n🗑️  Очистка таблиц..."
    
    total_deleted = 0
    
    models.each do |model|
      next unless table_exists?(model)
      
      begin
        count = model.count
        if count > 0
          model.delete_all
          puts "  ✅ #{model.name}: удалено #{count} записей"
          total_deleted += count
        else
          puts "  ⚪ #{model.name}: таблица уже пуста"
        end
      rescue => e
        puts "  ❌ Ошибка при очистке #{model.name}: #{e.message}"
      end
    end
    
    puts "\n📊 Итого удалено записей: #{total_deleted}"
  end

  def self.reset_sequences(models)
    return unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
    
    puts "\n🔄 Сброс последовательностей PostgreSQL..."
    
    models.each do |model|
      next unless table_exists?(model)
      
      begin
        sequence_name = "#{model.table_name}_id_seq"
        ActiveRecord::Base.connection.execute("ALTER SEQUENCE #{sequence_name} RESTART WITH 1;")
        puts "  ✅ Сброшена последовательность для #{model.name}"
      rescue => e
        puts "  ⚠️  Не удалось сбросить последовательность для #{model.name}: #{e.message}"
      end
    end
  end

  def self.table_exists?(model)
    ActiveRecord::Base.connection.table_exists?(model.table_name)
  end

  def self.print_database_stats
    stats = {}
    
    # Получаем количество записей в основных таблицах
    [UserRole, User, Region, City, ServiceCategory, Service, ServicePoint, 
     Partner, Client, Booking].each do |model|
      if table_exists?(model)
        stats[model.name] = model.count
      end
    end
    
    stats.each do |model_name, count|
      puts "  #{model_name}: #{count} записей"
    end
  end
end

# Запускаем очистку только если файл вызван напрямую
if __FILE__ == $0 || ENV['FORCE_RESET'] == 'true'
  DatabaseReset.perform!
end 