# Custom Variables Seeds
# Создание кастомных переменных для email шаблонов

puts "📝 Создание кастомных переменных для email шаблонов..."

# Получаем администратора для создания переменных
admin_user = User.find_by(email: 'admin@test.com') || User.where(role: UserRole.find_by(name: 'admin')).first || User.first

if admin_user.nil?
  puts "❌ Не найден администратор для создания переменных"
  return
end

puts "👤 Используем администратора: #{admin_user.email}"

# =====================================================
# КАСТОМНЫЕ ПЕРЕМЕННЫЕ (примеры)
# =====================================================

puts "📝 Создание кастомных переменных..."

custom_variables_data = [
  # Погодные условия
  {
    name: 'weather_warning',
    category: 'custom',
    description: 'Попередження про погодні умови',
    example_value: 'Увага! Завтра очікується дощ. Рекомендуємо зимові шини для безпечної їзди.'
  },
  {
    name: 'seasonal_recommendation',
    category: 'custom', 
    description: 'Сезонні рекомендації по шинах',
    example_value: 'З настанням зими радимо перейти на зимові шини для вашої безпеки.'
  },
  
  # Акции и скидки
  {
    name: 'current_promotion',
    category: 'custom',
    description: 'Поточна акція або знижка',
    example_value: 'Спеціальна пропозиція: знижка 15% на всі зимові шини до кінця місяця!'
  },
  {
    name: 'loyalty_bonus',
    category: 'custom',
    description: 'Бонус за лояльність',
    example_value: 'Як наш постійний клієнт, ви отримуєте додаткову знижку 5%'
  },
  
  # Дополнительные услуги
  {
    name: 'additional_services',
    category: 'custom',
    description: 'Додаткові послуги',
    example_value: 'Також пропонуємо: балансування коліс, заміну масла, діагностику підвіски'
  },
  {
    name: 'warranty_info',
    category: 'custom',
    description: 'Інформація про гарантію',
    example_value: 'Гарантія на встановлені шини складає 12 місяців або 20000 км пробігу'
  },
  
  # Контакты и время работы
  {
    name: 'emergency_contact',
    category: 'custom',
    description: 'Екстрений контакт',
    example_value: 'У випадку термінових питань телефонуйте: +380501234567 (цілодобово)'
  },
  {
    name: 'weekend_hours',
    category: 'custom',
    description: 'Режим роботи у вихідні',
    example_value: 'Вихідні: субота 9:00-15:00, неділя - вихідний'
  }
]

custom_variables_data.each do |var_data|
  variable = CustomVariable.find_or_create_by(name: var_data[:name]) do |var|
    var.category = var_data[:category]
    var.description = var_data[:description]
    var.example_value = var_data[:example_value]
    var.is_active = true
    var.created_by = admin_user
  end
  
  if variable.persisted?
    puts "✅ Створена змінна: #{variable.name}"
  else
    puts "❌ Помилка створення змінної #{var_data[:name]}: #{variable.errors.full_messages.join(', ')}"
  end
end

puts ""
puts "📊 Результат создания кастомных переменных:"
puts "📝 Всего кастомных переменных в системе: #{CustomVariable.count}"

# Статистика по категориям
puts ""
puts "📁 Переменные по категориям:"
CustomVariable.group(:category).count.each do |category, count|
  puts "  #{category}: #{count} шт."
end

puts ""
puts "🎯 Кастомные переменные готовы к использованию в email шаблонах!"
puts "💡 Их можно использовать в шаблонах как {имя_переменной}"
puts "⚙️  Управление переменными доступно в админ-панели: /admin/notifications/custom-variables" 