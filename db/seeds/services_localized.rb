# db/seeds/services_localized.rb
# Создание категорий услуг и услуг с поддержкой локализации (ru/uk)

puts "=== Обновление категорий услуг и услуг с локализацией ==="

# =============================================================================
# ОБНОВЛЕНИЕ КАТЕГОРИЙ УСЛУГ С ЛОКАЛИЗАЦИЕЙ
# =============================================================================

categories_data = [
  {
    name: 'Шиномонтаж',
    name_uk: 'Шиномонтаж',
    description: 'Услуги по монтажу, демонтажу и ремонту шин',
    description_uk: 'Послуги з монтажу, демонтажу та ремонту шин',
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Техническое обслуживание',
    name_uk: 'Технічне обслуговування',
    description: 'Диагностика, ремонт и обслуживание автомобилей',
    description_uk: 'Діагностика, ремонт та обслуговування автомобілів',
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Дополнительные услуги',
    name_uk: 'Додаткові послуги',
    description: 'Мойка, полировка и другие дополнительные услуги',
    description_uk: 'Мийка, полірування та інші додаткові послуги',
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Диагностика',
    name_uk: 'Діагностика',
    description: 'Компьютерная диагностика и проверка систем автомобиля',
    description_uk: 'Комп\'ютерна діагностика та перевірка систем автомобіля',
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Ремонт подвески',
    name_uk: 'Ремонт підвіски',
    description: 'Ремонт и замена элементов подвески',
    description_uk: 'Ремонт та заміна елементів підвіски',
    sort_order: 5,
    is_active: true
  }
]

puts "\n📁 Обновление категорий услуг..."

categories_created = 0
categories_updated = 0
categories = {}

categories_data.each do |category_data|
  begin
    category = ServiceCategory.find_or_initialize_by(name: category_data[:name])
    
    if category.persisted?
      category.update!(category_data)
      puts "  ✅ Обновлена категория: #{category.name} / #{category.name_uk} (ID: #{category.id})"
      categories_updated += 1
    else
      category.save!
      puts "  ✨ Создана категория: #{category.name} / #{category.name_uk} (ID: #{category.id})"
      categories_created += 1
    end
    
    categories[category.name] = category
  rescue => e
    puts "  ❌ Ошибка с категорией #{category_data[:name]}: #{e.message}"
  end
end

puts "📊 Категории - создано: #{categories_created}, обновлено: #{categories_updated}"

# =============================================================================
# ОБНОВЛЕНИЕ УСЛУГ С ЛОКАЛИЗАЦИЕЙ
# =============================================================================

services_data = [
  # === ШИНОМОНТАЖ ===
  {
    name: 'Замена шин',
    name_uk: 'Заміна шин',
    description: 'Профессиональная замена летних/зимних шин с балансировкой',
    description_uk: 'Професійна заміна літніх/зимових шин з балансуванням',
    category: 'Шиномонтаж',
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Балансировка колес',
    name_uk: 'Балансування коліс',
    description: 'Точная балансировка колес для комфортной езды',
    description_uk: 'Точне балансування коліс для комфортної їзди',
    category: 'Шиномонтаж',
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Ремонт проколов',
    name_uk: 'Ремонт проколів',
    description: 'Быстрый ремонт проколов и повреждений шин',
    description_uk: 'Швидкий ремонт проколів та пошкоджень шин',
    category: 'Шиномонтаж',
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Проверка давления в шинах',
    name_uk: 'Перевірка тиску в шинах',
    description: 'Бесплатная проверка и подкачка шин',
    description_uk: 'Безкоштовна перевірка та накачування шин',
    category: 'Шиномонтаж',
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Сезонное хранение шин',
    name_uk: 'Сезонне зберігання шин',
    description: 'Сезонное хранение шин в специальных условиях',
    description_uk: 'Сезонне зберігання шин у спеціальних умовах',
    category: 'Шиномонтаж',
    sort_order: 5,
    is_active: true
  },
  {
    name: 'Установка датчиков давления',
    name_uk: 'Встановлення датчиків тиску',
    description: 'Установка и настройка датчиков давления в шинах',
    description_uk: 'Встановлення та налаштування датчиків тиску в шинах',
    category: 'Шиномонтаж',
    sort_order: 6,
    is_active: true
  },

  # === ТЕХНИЧЕСКОЕ ОБСЛУЖИВАНИЕ ===
  {
    name: 'Замена масла',
    name_uk: 'Заміна масла',
    description: 'Замена моторного масла и масляного фильтра',
    description_uk: 'Заміна моторного масла та масляного фільтра',
    category: 'Техническое обслуживание',
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Замена тормозных колодок',
    name_uk: 'Заміна гальмівних колодок',
    description: 'Замена передних или задних тормозных колодок',
    description_uk: 'Заміна передніх або задніх гальмівних колодок',
    category: 'Техническое обслуживание',
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Замена воздушного фильтра',
    name_uk: 'Заміна повітряного фільтра',
    description: 'Замена воздушного фильтра двигателя',
    description_uk: 'Заміна повітряного фільтра двигуна',
    category: 'Техническое обслуживание',
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Замена свечей зажигания',
    name_uk: 'Заміна свічок запалювання',
    description: 'Замена свечей зажигания для лучшей работы двигателя',
    description_uk: 'Заміна свічок запалювання для кращої роботи двигуна',
    category: 'Техническое обслуживание',
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Замена амортизаторов',
    name_uk: 'Заміна амортизаторів',
    description: 'Замена передних или задних амортизаторов',
    description_uk: 'Заміна передніх або задніх амортизаторів',
    category: 'Техническое обслуживание',
    sort_order: 5,
    is_active: true
  },
  {
    name: 'Замена аккумулятора',
    name_uk: 'Заміна акумулятора',
    description: 'Замена и утилизация старого аккумулятора',
    description_uk: 'Заміна та утилізація старого акумулятора',
    category: 'Техническое обслуживание',
    sort_order: 6,
    is_active: true
  },

  # === ДОПОЛНИТЕЛЬНЫЕ УСЛУГИ ===
  {
    name: 'Мойка автомобиля',
    name_uk: 'Мийка автомобіля',
    description: 'Наружная мойка автомобиля с сушкой',
    description_uk: 'Зовнішня мийка автомобіля з сушінням',
    category: 'Дополнительные услуги',
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Химчистка салона',
    name_uk: 'Хімчистка салону',
    description: 'Профессиональная химчистка салона автомобиля',
    description_uk: 'Професійна хімчистка салону автомобіля',
    category: 'Дополнительные услуги',
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Полировка кузова',
    name_uk: 'Полірування кузова',
    description: 'Профессиональная полировка лакокрасочного покрытия',
    description_uk: 'Професійне полірування лакофарбового покриття',
    category: 'Дополнительные услуги',
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Заправка кондиционера',
    name_uk: 'Заправка кондиціонера',
    description: 'Заправка и диагностика системы кондиционирования',
    description_uk: 'Заправка та діагностика системи кондиціонування',
    category: 'Дополнительные услуги',
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Тонировка стекол',
    name_uk: 'Тонування скла',
    description: 'Профессиональная тонировка стекол автомобиля',
    description_uk: 'Професійне тонування скла автомобіля',
    category: 'Дополнительные услуги',
    sort_order: 5,
    is_active: true
  },
  {
    name: 'Установка сигнализации',
    name_uk: 'Встановлення сигналізації',
    description: 'Установка и настройка автомобильной сигнализации',
    description_uk: 'Встановлення та налаштування автомобільної сигналізації',
    category: 'Дополнительные услуги',
    sort_order: 6,
    is_active: true
  },

  # === ДИАГНОСТИКА ===
  {
    name: 'Компьютерная диагностика',
    name_uk: 'Комп\'ютерна діагностика',
    description: 'Полная компьютерная диагностика автомобиля',
    description_uk: 'Повна комп\'ютерна діагностика автомобіля',
    category: 'Диагностика',
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Диагностика ходовой части',
    name_uk: 'Діагностика ходової частини',
    description: 'Диагностика подвески и ходовой части',
    description_uk: 'Діагностика підвіски та ходової частини',
    category: 'Диагностика',
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Проверка развал-схождения',
    name_uk: 'Перевірка розвал-сходження',
    description: 'Проверка и настройка углов установки колес',
    description_uk: 'Перевірка та налаштування кутів установки коліс',
    category: 'Диагностика',
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Диагностика двигателя',
    name_uk: 'Діагностика двигуна',
    description: 'Диагностика работы двигателя и его систем',
    description_uk: 'Діагностика роботи двигуна та його систем',
    category: 'Диагностика',
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Проверка тормозной системы',
    name_uk: 'Перевірка гальмівної системи',
    description: 'Диагностика тормозной системы автомобиля',
    description_uk: 'Діагностика гальмівної системи автомобіля',
    category: 'Диагностика',
    sort_order: 5,
    is_active: true
  },

  # === РЕМОНТ ПОДВЕСКИ ===
  {
    name: 'Замена стоек стабилизатора',
    name_uk: 'Заміна стійок стабілізатора',
    description: 'Замена стоек стабилизатора поперечной устойчивости',
    description_uk: 'Заміна стійок стабілізатора поперечної стійкості',
    category: 'Ремонт подвески',
    sort_order: 1,
    is_active: true
  },
  {
    name: 'Замена шаровых опор',
    name_uk: 'Заміна кульових опор',
    description: 'Замена шаровых опор передней подвески',
    description_uk: 'Заміна кульових опор передньої підвіски',
    category: 'Ремонт подвески',
    sort_order: 2,
    is_active: true
  },
  {
    name: 'Замена рулевых тяг',
    name_uk: 'Заміна рульових тяг',
    description: 'Замена рулевых тяг и наконечников',
    description_uk: 'Заміна рульових тяг та наконечників',
    category: 'Ремонт подвески',
    sort_order: 3,
    is_active: true
  },
  {
    name: 'Замена пружин',
    name_uk: 'Заміна пружин',
    description: 'Замена пружин передней или задней подвески',
    description_uk: 'Заміна пружин передньої або задньої підвіски',
    category: 'Ремонт подвески',
    sort_order: 4,
    is_active: true
  },
  {
    name: 'Замена сайлентблоков',
    name_uk: 'Заміна сайлентблоків',
    description: 'Замена сайлентблоков рычагов подвески',
    description_uk: 'Заміна сайлентблоків важелів підвіски',
    category: 'Ремонт подвески',
    sort_order: 5,
    is_active: true
  }
]

puts "\n🔧 Обновление услуг..."

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
  
  begin
    service = Service.find_or_initialize_by(name: service_data[:name])
    
    if service.persisted?
      service.update!(service_attrs)
      puts "  ✅ Обновлена услуга: #{service.name} / #{service.name_uk} (ID: #{service.id}, Категория: #{category.name})"
      services_updated += 1
    else
      service.assign_attributes(service_attrs)
      service.save!
      puts "  ✨ Создана услуга: #{service.name} / #{service.name_uk} (ID: #{service.id}, Категория: #{category.name})"
      services_created += 1
    end
    
    services_by_category[category.name] << service
  rescue => e
    puts "  ❌ Ошибка с услугой #{service_data[:name]}: #{e.message}"
  end
end

# =============================================================================
# ИТОГОВАЯ СТАТИСТИКА
# =============================================================================
puts "\n" + "="*80
puts "📊 ИТОГОВАЯ СТАТИСТИКА ЛОКАЛИЗОВАННЫХ УСЛУГ"
puts "="*80
puts "📁 Категории услуг - создано: #{categories_created}, обновлено: #{categories_updated}"
puts "🔧 Услуг - создано: #{services_created}, обновлено: #{services_updated}"
puts "✨ Активных категорий: #{ServiceCategory.where(is_active: true).count}"
puts "✨ Активных услуг: #{Service.where(is_active: true).count}"

puts "\n📈 Услуги по категориям:"
services_by_category.each do |category_name, category_services|
  puts "  #{category_name}: #{category_services.count} услуг"
  category_services.each do |service|
    puts "    • #{service.name} / #{service.name_uk}"
  end
end

puts "\n🌍 Поддерживаемые языки:"
puts "  • Русский (name, description)"
puts "  • Украинский (name_uk, description_uk)"
puts "  • Методы локализации: localized_name(locale), localized_description(locale)"

puts "\n📋 ID категорий для справки:"
ServiceCategory.order(:sort_order).each do |category|
  puts "  #{category.name} / #{category.name_uk}: ID #{category.id}"
end

puts "\n" + "="*80
puts "🎉 Локализованные категории услуг и услуги успешно обновлены!"
puts "="*80 