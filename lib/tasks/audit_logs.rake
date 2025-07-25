namespace :audit_logs do
  desc 'Очистка старых аудит логов (по умолчанию старше 30 дней)'
  task :cleanup, [:days] => :environment do |t, args|
    days_ago = (args[:days] || 30).to_i
    
    puts "🧹 Начинаю очистку аудит логов старше #{days_ago} дней..."
    
    # Подсчитываем количество записей для удаления
    old_logs_count = SystemLog.cleanup_old(days_ago).count
    
    if old_logs_count == 0
      puts "✅ Нет логов для удаления (старше #{days_ago} дней)"
      next
    end
    
    puts "📊 Найдено #{old_logs_count} записей для удаления"
    
    # Удаляем пакетами для избежания блокировок
    batch_size = 1000
    deleted_count = 0
    
    loop do
      batch = SystemLog.cleanup_old(days_ago).limit(batch_size)
      break if batch.empty?
      
      batch_count = batch.count
      batch.delete_all
      deleted_count += batch_count
      
      puts "🗑️  Удалено #{deleted_count}/#{old_logs_count} записей..."
      
      # Небольшая пауза между пакетами
      sleep(0.1) if batch_count == batch_size
      
      break if batch_count < batch_size
    end
    
    puts "✅ Очистка завершена! Удалено #{deleted_count} записей"
    puts "📈 Освобождено место в базе данных"
  end

  desc 'Статистика по аудит логам'
  task :stats, [:days] => :environment do |t, args|
    days_ago = (args[:days] || 30).to_i
    
    puts "📊 Статистика аудит логов за последние #{days_ago} дней:"
    puts "=" * 50
    
    # Общая статистика
    total_logs = SystemLog.where('created_at >= ?', days_ago.days.ago).count
    puts "📋 Всего записей: #{total_logs}"
    
    if total_logs == 0
      puts "ℹ️  Нет данных для отображения статистики"
      next
    end
    
    # Статистика по действиям
    puts "\n🎯 По типам действий:"
    SystemLog.stats_by_action(days_ago).each do |action, count|
      percentage = (count.to_f / total_logs * 100).round(1)
      puts "  #{action.ljust(15)} #{count.to_s.rjust(6)} (#{percentage}%)"
    end
    
    # Статистика по пользователям
    puts "\n👥 Самые активные пользователи:"
    SystemLog.stats_by_user(days_ago).sort_by { |_, count| -count }.first(10).each_with_index do |(email, count), index|
      puts "  #{(index + 1).to_s.rjust(2)}. #{email.ljust(30)} #{count} действий"
    end
    
    # Статистика по ресурсам
    puts "\n🏗️  Самые изменяемые ресурсы:"
    SystemLog.most_active_resources(days_ago, 10).each_with_index do |(resource_type, count), index|
      puts "  #{(index + 1).to_s.rjust(2)}. #{resource_type.ljust(20)} #{count} изменений"
    end
    
    # Статистика по дням
    puts "\n📅 Активность по дням:"
    daily_stats = SystemLog.where('created_at >= ?', days_ago.days.ago)
                           .group("DATE(created_at)")
                           .count
                           .sort_by { |date, _| date }
                           .last(7)
    
    daily_stats.each do |date, count|
      bar = '█' * (count / [total_logs / 50, 1].max)
      puts "  #{date} #{count.to_s.rjust(4)} #{bar}"
    end
    
    puts "\n" + "=" * 50
  end

  desc 'Экспорт аудит логов в CSV'
  task :export, [:days, :output_file] => :environment do |t, args|
    days_ago = (args[:days] || 7).to_i
    output_file = args[:output_file] || "audit_logs_#{Date.current.strftime('%Y%m%d')}.csv"
    
    puts "📤 Экспорт аудит логов за последние #{days_ago} дней в файл: #{output_file}"
    
    require 'csv'
    
    logs = SystemLog.includes(:user)
                   .where('created_at >= ?', days_ago.days.ago)
                   .order(:created_at)
    
    if logs.empty?
      puts "ℹ️  Нет данных для экспорта"
      next
    end
    
    CSV.open(output_file, 'w', write_headers: true, headers: [
      'Дата и время',
      'Пользователь',
      'Действие',
      'Ресурс',
      'ID ресурса',
      'IP адрес',
      'User Agent',
      'Изменения'
    ]) do |csv|
      logs.find_each do |log|
        csv << [
          log.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          log.user&.full_name || 'Система',
          log.action_description,
          log.resource_type,
          log.resource_id,
          log.ip_address,
          log.user_agent,
          log.changes&.to_json
        ]
      end
    end
    
    puts "✅ Экспорт завершен! Записей: #{logs.count}"
    puts "📁 Файл сохранен: #{File.expand_path(output_file)}"
  end

  desc 'Тест системы аудита'
  task :test => :environment do
    puts "🧪 Тестирование системы аудита..."
    
    # Создаем тестового пользователя
    test_user = User.find_by(email: 'audit_test@example.com')
    unless test_user
      puts "👤 Создаю тестового пользователя..."
      test_user = User.create!(
        email: 'audit_test@example.com',
        first_name: 'Тест',
        last_name: 'Аудита',
        role_id: UserRole.find_by(name: 'admin')&.id || 1,
        password: 'password123'
      )
    end
    
    # Тестируем различные типы логирования
    puts "📝 Тестирую логирование создания..."
    SystemLog.log_create(test_user, 'TestResource', 123, { name: 'Test' })
    
    puts "📝 Тестирую логирование обновления..."
    SystemLog.log_update(test_user, 'TestResource', 123, { name: 'Test' }, { name: 'Updated Test' })
    
    puts "📝 Тестирую логирование удаления..."
    SystemLog.log_delete(test_user, 'TestResource', 123, { name: 'Updated Test' })
    
    puts "📝 Тестирую логирование блокировки..."
    SystemLog.log_suspend(test_user, test_user, 'Тестовая блокировка')
    
    puts "📝 Тестирую логирование разблокировки..."
    SystemLog.log_unsuspend(test_user, test_user)
    
    # Проверяем созданные записи
    recent_logs = SystemLog.where(user: test_user).recent.limit(5)
    puts "\n✅ Создано #{recent_logs.count} тестовых записей:"
    
    recent_logs.each do |log|
      puts "  - #{log.action_description} (#{log.created_at.strftime('%H:%M:%S')})"
    end
    
    puts "\n🧹 Очищаю тестовые данные..."
    SystemLog.where(user: test_user).delete_all
    test_user.destroy
    
    puts "✅ Тест системы аудита завершен успешно!"
  end
end 