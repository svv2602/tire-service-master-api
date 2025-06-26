# Создание услуг для сервисных точек
puts "=== Создание услуг ==="

# Очищаем существующие услуги для идемпотентности
existing_count = Service.count
puts "📊 Существующих услуг: #{existing_count}"

if existing_count > 0
  puts "ℹ️  Услуги уже существуют. Пропускаем создание для избежания дублирования."
  puts "   Если нужно пересоздать услуги, используйте: Service.destroy_all перед запуском"
  exit
end

# =============================================================================
# ПОИСК КАТЕГОРИЙ УСЛУГ
# =============================================================================

# Найдем существующие категории
categories = {}
ServiceCategory.all.each do |category|
  categories[category.name.downcase] = category.id
end

puts "📁 Доступные категории:"
categories.each { |name, id| puts "  #{id}: #{name}" }

# Если категорий мало, создадим дополнительные
if categories.size < 3
  puts "\n🔧 Создание дополнительных категорий..."
  
  additional_categories = [
    { name: 'Техническое обслуживание', description: 'Диагностика и ремонт автомобилей' },
    { name: 'Дополнительные услуги', description: 'Мойка, полировка и другие услуги' }
  ]
  
  additional_categories.each do |cat_data|
    unless ServiceCategory.find_by(name: cat_data[:name])
      category = ServiceCategory.create!(
        name: cat_data[:name],
        description: cat_data[:description],
        is_active: true,
        sort_order: ServiceCategory.count + 1
      )
      categories[category.name.downcase] = category.id
      puts "  ✅ Создана категория: #{category.name} (ID: #{category.id})"
    end
  end
end

# Обновляем список категорий
categories = {}
ServiceCategory.all.each do |category|
  categories[category.name.downcase] = category.id
end

# =============================================================================
# УСЛУГИ ПО КАТЕГОРИЯМ
# =============================================================================

# Найдем подходящие категории для наших услуг
tire_category_id = categories.values.first # Используем первую доступную категорию
maintenance_category_id = categories.values[1] || tire_category_id # Вторую или первую
additional_category_id = categories.values[2] || tire_category_id # Третью или первую

services_data = [
  # =============================================================================
  # КАТЕГОРИЯ 1: ШИНОМОНТАЖ (основные услуги)
  # =============================================================================
  {
    name: 'Заміна шин',
    description: 'Професійна заміна літніх/зимових шин з балансуванням',
    category_id: tire_category_id,
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Балансування коліс',
    description: 'Точне балансування коліс для комфортної їзди',
    category_id: tire_category_id,
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Ремонт проколів',
    description: 'Швидкий ремонт проколів та пошкоджень шин',
    category_id: tire_category_id,
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Перевірка тиску',
    description: 'Безкоштовна перевірка та накачування шин',
    category_id: tire_category_id,
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Зберігання шин',
    description: 'Сезонне зберігання шин в спеціальних умовах',
    category_id: tire_category_id,
    sort_order: 5,
    is_active: true
  },

  # =============================================================================
  # КАТЕГОРИЯ 2: ТЕХНІЧНЕ ОБСЛУГОВУВАННЯ
  # =============================================================================
  {
    name: 'Заміна масла',
    description: 'Заміна моторного масла та масляного фільтра',
    category_id: maintenance_category_id,
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Діагностика ходової',
    description: 'Комп\'ютерна діагностика підвіски та ходової частини',
    category_id: maintenance_category_id,
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Заміна гальмівних колодок',
    description: 'Заміна передніх або задніх гальмівних колодок',
    category_id: maintenance_category_id,
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Регулювання розвал-сходження',
    description: 'Точне налаштування кутів установки коліс',
    category_id: maintenance_category_id,
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Заміна амортизаторів',
    description: 'Заміна передніх або задніх амортизаторів',
    category_id: maintenance_category_id,
    sort_order: 5,
    is_active: true
  },

  # =============================================================================
  # КАТЕГОРИЯ 3: ДОДАТКОВІ ПОСЛУГИ
  # =============================================================================
  {
    name: 'Мийка автомобіля',
    description: 'Зовнішня мийка автомобіля з сушінням',
    category_id: additional_category_id,
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Хімчистка салону',
    description: 'Професійна хімчистка салону автомобіля',
    category_id: additional_category_id,
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Полірування кузова',
    description: 'Професійне полірування лакофарбового покриття',
    category_id: additional_category_id,
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Заправка кондиціонера',
    description: 'Заправка та діагностика системи кондиціонування',
    category_id: additional_category_id,
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Тонування скла',
    description: 'Професійна тонування скла автомобіля',
    category_id: additional_category_id,
    sort_order: 5,
    is_active: true
  }
]

# =============================================================================
# СОЗДАНИЕ УСЛУГ
# =============================================================================

puts "\n🔧 Создание услуг..."

created_count = 0
services_by_category = {}

services_data.each do |service_data|
  begin
    service = Service.create!(
      name: service_data[:name],
      description: service_data[:description],
      category_id: service_data[:category_id],
      sort_order: service_data[:sort_order],
      is_active: service_data[:is_active]
    )
    
    # Группируем для статистики
    category_name = ServiceCategory.find(service_data[:category_id]).name
    services_by_category[category_name] ||= []
    services_by_category[category_name] << service
    
    puts "  ✅ #{service.name} (категория: #{category_name})"
    created_count += 1
  rescue => e
    puts "  ❌ Ошибка при создании '#{service_data[:name]}': #{e.message}"
  end
end

# =============================================================================
# ИТОГОВАЯ СТАТИСТИКА
# =============================================================================
puts "\n" + "="*60
puts "📊 ИТОГОВАЯ СТАТИСТИКА УСЛУГ"
puts "="*60
puts "📚 Всего услуг создано: #{created_count}/#{services_data.length}"
puts "✨ Активных услуг: #{Service.where(is_active: true).count}"

puts "\n📁 Услуги по категориям:"
services_by_category.each do |category_name, services|
  puts "  #{category_name}: #{services.length} услуг"
  services.each do |service|
    puts "    • #{service.name}"
  end
end

puts "="*60
puts "🎉 Услуги созданы успешно!" 