# lib/tasks/seeds_improved.rake
# Rake задачи для улучшенной системы загрузки seeds

namespace :db do
  namespace :seed do
    desc "Полная перезагрузка базы данных с улучшенными seeds"
    task :full_reset => :environment do
      puts "🚀 Запуск полной перезагрузки базы данных..."
      load File.join(Rails.root, 'db', 'seeds_new.rb')
    end

    desc "Быстрая загрузка seeds без очистки БД"
    task :fast => :environment do
      puts "⚡ Быстрая загрузка seeds (без очистки БД)..."
      ENV['SKIP_RESET'] = 'true'
      load File.join(Rails.root, 'db', 'seeds_new.rb')
    end

    desc "Только очистка базы данных"
    task :reset_only => :environment do
      puts "🧹 Только очистка базы данных..."
      load File.join(Rails.root, 'db', 'seeds', '00_database_reset.rb')
      DatabaseReset.perform!
    end

    desc "Проверка и исправление последовательностей PostgreSQL"
    task :fix_sequences => :environment do
      puts "🔢 Проверка последовательностей PostgreSQL..."
      
      if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
        begin
          require File.join(Rails.root, 'app', 'models', 'concerns', 'database_sequences.rb')
          DatabaseSequences.fix_all_sequences!
          puts "✅ Все последовательности исправлены"
        rescue => e
          puts "❌ Ошибка: #{e.message}"
        end
      else
        puts "⚠️  Задача доступна только для PostgreSQL"
      end
    end

    desc "Статистика по базе данных"
    task :stats => :environment do
      puts "📊 === СТАТИСТИКА БАЗЫ ДАННЫХ ==="
      
      stats = {
        'Роли пользователей' => UserRole.count,
        'Пользователи' => User.count,
        'Администраторы' => Administrator.count,
        'Партнеры' => Partner.count,
        'Клиенты' => Client.count,
        'Регионы' => Region.count,
        'Города' => City.count,
        'Категории услуг' => ServiceCategory.count,
        'Услуги' => Service.count,
        'Сервисные точки' => ServicePoint.count,
        'Сервисные посты' => ServicePost.count,
        'Шаблоны расписания' => ScheduleTemplate.count,
        'Статьи' => Article.count,
        'Бронирования' => Booking.count,
        'Отзывы' => Review.count
      }

      total_records = stats.values.sum
      
      puts "📈 Количество записей по таблицам:"
      stats.each do |name, count|
        percentage = total_records > 0 ? (count.to_f / total_records * 100).round(1) : 0
        puts "  #{name.ljust(25)}: #{count.to_s.rjust(6)} (#{percentage}%)"
      end
      
      puts "\n📊 Итого записей: #{total_records}"
      
      # Проверяем критические компоненты
      critical_issues = []
      critical_issues << "❌ Нет ролей пользователей" if UserRole.count == 0
      critical_issues << "❌ Нет администратора" if Administrator.count == 0
      critical_issues << "❌ Нет регионов" if Region.count == 0
      critical_issues << "❌ Нет городов" if City.count == 0
      critical_issues << "❌ Нет услуг" if Service.count == 0
      
      if critical_issues.any?
        puts "\n⚠️  КРИТИЧЕСКИЕ ПРОБЛЕМЫ:"
        critical_issues.each { |issue| puts "  #{issue}" }
      else
        puts "\n✅ Все критические компоненты присутствуют"
      end
    end

    desc "Валидация целостности данных"
    task :validate => :environment do
      puts "🔍 === ВАЛИДАЦИЯ ЦЕЛОСТНОСТИ ДАННЫХ ==="
      
      errors = []
      warnings = []
      
      # Проверяем пользователей без ролей
      users_without_roles = User.left_joins(:role).where(user_roles: { id: nil }).count
      if users_without_roles > 0
        errors << "#{users_without_roles} пользователей без ролей"
      end
      
      # Проверяем города без регионов
      cities_without_regions = City.left_joins(:region).where(regions: { id: nil }).count
      if cities_without_regions > 0
        errors << "#{cities_without_regions} городов без регионов"
      end
      
      # Проверяем услуги без категорий
      services_without_categories = Service.left_joins(:category).where(service_categories: { id: nil }).count
      if services_without_categories > 0
        errors << "#{services_without_categories} услуг без категорий"
      end
      
      # Проверяем сервисные точки без городов
      service_points_without_cities = ServicePoint.left_joins(:city).where(cities: { id: nil }).count
      if service_points_without_cities > 0
        errors << "#{service_points_without_cities} сервисных точек без городов"
      end
      
      # Проверяем партнеров без пользователей
      partners_without_users = Partner.left_joins(:user).where(users: { id: nil }).count
      if partners_without_users > 0
        warnings << "#{partners_without_users} партнеров без пользователей"
      end
      
      # Проверяем клиентов без пользователей
      clients_without_users = Client.left_joins(:user).where(users: { id: nil }).count
      if clients_without_users > 0
        warnings << "#{clients_without_users} клиентов без пользователей"
      end
      
      # Выводим результаты
      if errors.any?
        puts "\n❌ КРИТИЧЕСКИЕ ОШИБКИ:"
        errors.each { |error| puts "  • #{error}" }
      end
      
      if warnings.any?
        puts "\n⚠️  ПРЕДУПРЕЖДЕНИЯ:"
        warnings.each { |warning| puts "  • #{warning}" }
      end
      
      if errors.empty? && warnings.empty?
        puts "\n✅ Целостность данных в порядке!"
      end
      
      puts "\n📋 Рекомендации:"
      puts "  • Для исправления ошибок запустите: rake db:seed:full_reset"
      puts "  • Для проверки последовательностей: rake db:seed:fix_sequences"
    end

    desc "Создание тестовых бронирований"
    task :test_bookings => :environment do
      puts "📅 === СОЗДАНИЕ ТЕСТОВЫХ БРОНИРОВАНИЙ ==="
      
      # Проверяем наличие необходимых данных
      unless Client.any? && ServicePoint.any? && Service.any?
        puts "❌ Недостаточно данных для создания бронирований"
        puts "   Запустите сначала: rake db:seed:full_reset"
        exit 1
      end
      
      client = Client.first
      service_point = ServicePoint.first
      service = Service.first
      
      # Создаем несколько тестовых бронирований
      3.times do |i|
        booking_date = Date.current + (i + 1).days
        
        booking = Booking.create!(
          client: client,
          service_point: service_point,
          service: service,
          booking_date: booking_date,
          start_time: "#{10 + i}:00",
          end_time: "#{11 + i}:00",
          status_id: 1, # pending
          notes: "Тестовое бронирование #{i + 1}"
        )
        
        puts "  ✅ Создано бронирование: #{booking.booking_date} в #{booking.start_time}"
      end
      
      puts "\n📊 Всего бронирований: #{Booking.count}"
    end
  end
end

# Алиасы для удобства
namespace :seeds do
  desc "Полная перезагрузка (алиас для db:seed:full_reset)"
  task :reset => 'db:seed:full_reset'
  
  desc "Быстрая загрузка (алиас для db:seed:fast)"
  task :fast => 'db:seed:fast'
  
  desc "Статистика (алиас для db:seed:stats)"
  task :stats => 'db:seed:stats'
end 