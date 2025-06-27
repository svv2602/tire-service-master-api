# db/seeds/03_services.rb
# Создание категорий услуг и самих услуг с динамическими ID

puts '=== Создание категорий услуг и услуг ==='

# =============================================================================
# СОЗДАНИЕ КАТЕГОРИЙ УСЛУГ
# =============================================================================

categories_data = [
  {
    name: 'Шиномонтаж',
    description: 'Услуги по монтажу, демонтажу и ремонту шин',
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Техническое обслуживание',
    description: 'Диагностика, ремонт и обслуживание автомобилей',
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Дополнительные услуги',
    description: 'Мойка, полировка и другие дополнительные услуги',
    sort_order: 3,
    is_active: true
  }
]

puts "\n📁 Создание категорий услуг..."

categories_created = 0
categories_updated = 0
categories = {}

categories_data.each do |category_data|
  category = ServiceCategory.find_or_initialize_by(name: category_data[:name])
  
  if category.persisted?
    if category.update(category_data)
      puts "  ✅ Обновлена категория: #{category.name} (ID: #{category.id})"
      categories_updated += 1
    else
      puts "  ❌ Ошибка обновления категории #{category_data[:name]}: #{category.errors.full_messages.join(', ')}"
    end
  else
    if category.save
      puts "  ✨ Создана категория: #{category.name} (ID: #{category.id})"
      categories_created += 1
    else
      puts "  ❌ Ошибка создания категории #{category_data[:name]}: #{category.errors.full_messages.join(', ')}"
    end
  end
  
  # Сохраняем категорию для использования в услугах
  categories[category.name] = category if category.persisted?
end

puts "📊 Категории - создано: #{categories_created}, обновлено: #{categories_updated}"

# =============================================================================
# СОЗДАНИЕ УСЛУГ
# =============================================================================

services_data = [
  # Шиномонтаж
  {
    name: 'Заміна шин',
    description: 'Професійна заміна літніх/зимових шин з балансуванням',
    category: 'Шиномонтаж',
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Балансування коліс',
    description: 'Точне балансування коліс для комфортної їзди',
    category: 'Шиномонтаж',
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Ремонт проколів',
    description: 'Швидкий ремонт проколів та пошкоджень шин',
    category: 'Шиномонтаж',
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Перевірка тиску',
    description: 'Безкоштовна перевірка та накачування шин',
    category: 'Шиномонтаж',
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Зберігання шин',
    description: 'Сезонне зберігання шин в спеціальних умовах',
    category: 'Шиномонтаж',
    sort_order: 5,
    is_active: true
  },
  
  # Техническое обслуживание
  {
    name: 'Заміна масла',
    description: 'Заміна моторного масла та масляного фільтра',
    category: 'Техническое обслуживание',
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Діагностика ходової',
    description: 'Комп\'ютерна діагностика підвіски та ходової частини',
    category: 'Техническое обслуживание',
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Заміна гальмівних колодок',
    description: 'Заміна передніх або задніх гальмівних колодок',
    category: 'Техническое обслуживание',
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Регулювання розвал-сходження',
    description: 'Точне налаштування кутів установки коліс',
    category: 'Техническое обслуживание',
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Заміна амортизаторів',
    description: 'Заміна передніх або задніх амортизаторів',
    category: 'Техническое обслуживание',
    sort_order: 5,
    is_active: true
  },
  
  # Дополнительные услуги
  {
    name: 'Мийка автомобіля',
    description: 'Зовнішня мийка автомобіля з сушінням',
    category: 'Дополнительные услуги',
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Хімчистка салону',
    description: 'Професійна хімчистка салону автомобіля',
    category: 'Дополнительные услуги',
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Полірування кузова',
    description: 'Професійне полірування лакофарбового покриття',
    category: 'Дополнительные услуги',
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Заправка кондиціонера',
    description: 'Заправка та діагностика системи кондиціонування',
    category: 'Дополнительные услуги',
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Тонування скла',
    description: 'Професійна тонування скла автомобіля',
    category: 'Дополнительные услуги',
    sort_order: 5,
    is_active: true
  }
]

puts "\n🔧 Создание услуг..."

services_created = 0
services_updated = 0
services_by_category = Hash.new { |h, k| h[k] = [] }

services_data.each do |service_data|
  # Получаем категорию по названию
  category = categories[service_data[:category]]
  
  unless category
    puts "  ❌ Категория '#{service_data[:category]}' не найдена для услуги '#{service_data[:name]}'"
    next
  end
  
  # Подготавливаем данные услуги
  service_attrs = service_data.except(:category).merge(category_id: category.id)
  
  # Находим или создаем услугу
  service = Service.find_or_initialize_by(name: service_data[:name])
  
  if service.persisted?
    if service.update(service_attrs)
      puts "  ✅ Обновлена услуга: #{service.name} (ID: #{service.id}, Категория: #{category.name})"
      services_updated += 1
    else
      puts "  ❌ Ошибка обновления услуги #{service_data[:name]}: #{service.errors.full_messages.join(', ')}"
    end
  else
    service.assign_attributes(service_attrs)
    if service.save
      puts "  ✨ Создана услуга: #{service.name} (ID: #{service.id}, Категория: #{category.name})"
      services_created += 1
    else
      puts "  ❌ Ошибка создания услуги #{service_data[:name]}: #{service.errors.full_messages.join(', ')}"
    end
  end
  
  # Группируем услуги по категориям для статистики
  if service.persisted?
    services_by_category[category.name] << service
  end
end

puts "\n📊 Результат:"
puts "  Услуги - создано: #{services_created}, обновлено: #{services_updated}"
puts "  Всего услуг в системе: #{Service.count}"

# Статистика по категориям
puts "\n📈 Услуги по категориям:"
services_by_category.each do |category_name, category_services|
  puts "  #{category_name}: #{category_services.count} услуг"
  category_services.each do |service|
    puts "    - #{service.name} (ID: #{service.id})"
  end
end

# Выводим ID категорий и услуг для справки
puts "\n📋 ID категорий услуг:"
ServiceCategory.all.each do |category|
  puts "  #{category.name}: ID #{category.id}"
end

puts "\n📋 ID основных услуг:"
Service.limit(10).each do |service|
  puts "  #{service.name}: ID #{service.id}"
end

puts "✅ Категории услуг и услуги успешно созданы/обновлены!" 