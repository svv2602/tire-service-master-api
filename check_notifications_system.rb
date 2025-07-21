puts "🔍 Проверка системы уведомлений Tire Service"
puts "=" * 50

# Проверка таблиц
puts "\n📋 Проверка таблиц:"
tables_check = {
  'notifications' => Notification.table_exists?,
  'notification_types' => NotificationType.table_exists?
}

tables_check.each do |table, exists|
  status = exists ? "✅ существует" : "❌ не существует"
  puts "  - #{table}: #{status}"
end

# Проверка полей notifications
if Notification.table_exists?
  puts "\n📝 Поля таблицы notifications:"
  Notification.column_names.each { |col| puts "  - #{col}" }
  
  puts "\n📊 Статистика уведомлений:"
  puts "  - Всего уведомлений: #{Notification.count}"
  
  if Notification.count > 0
    puts "  - По приоритетам:"
    Notification.group(:priority).count.each { |priority, count| puts "    * #{priority}: #{count}" }
    
    puts "  - По категориям:"
    Notification.group(:category).count.each { |category, count| puts "    * #{category}: #{count}" }
  end
end

# Проверка типов уведомлений
if NotificationType.table_exists?
  puts "\n📋 Типы уведомлений:"
  puts "  - Всего типов: #{NotificationType.count}"
  
  if NotificationType.count > 0
    NotificationType.all.each do |type|
      puts "    * #{type.name} (ID: #{type.id})"
    end
  end
end

# Проверка пользователей для тестирования
puts "\n👥 Пользователи для тестирования:"
admin = User.find_by(email: 'admin@test.com')
if admin
  puts "  - Админ: ✅ найден (ID: #{admin.id})"
  notifications_count = Notification.where(recipient_type: 'User', recipient_id: admin.id).count
  puts "    * Уведомлений для админа: #{notifications_count}"
else
  puts "  - Админ: ❌ не найден"
end

puts "\n🔧 Проверка завершена!" 