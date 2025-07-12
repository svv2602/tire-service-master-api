#!/usr/bin/env ruby

# Тестирование логики системы конфликтов бронирований
# Проверяем правильность обработки временных конфликтов и конфликтов загруженности

puts "🔍 АНАЛИЗ ЛОГИКИ СИСТЕМЫ КОНФЛИКТОВ БРОНИРОВАНИЙ"
puts "=" * 60

# Функция для красивого вывода
def log_section(title)
  puts "\n📋 #{title}"
  puts "-" * 40
end

def log_info(message)
  puts "ℹ️  #{message}"
end

def log_success(message)
  puts "✅ #{message}"
end

def log_warning(message)
  puts "⚠️  #{message}"
end

def log_error(message)
  puts "❌ #{message}"
end

# 1. Проверяем структуру данных бронирований
log_section("СТРУКТУРА ДАННЫХ БРОНИРОВАНИЙ")

# Найдем тестовые данные
service_point = ServicePoint.first
if service_point.nil?
  log_error "Нет сервисных точек в системе"
  exit 1
end

log_info "Тестовая сервисная точка: #{service_point.name} (ID: #{service_point.id})"

# Проверяем посты
posts = service_point.service_posts.active
log_info "Активных постов: #{posts.count}"
posts.each do |post|
  log_info "  - Пост #{post.post_number}: #{post.name} (категория: #{post.service_category&.name}, длительность слота: #{post.slot_duration} мин)"
end

# Проверяем бронирования
bookings = service_point.bookings.upcoming.limit(5)
log_info "Будущих бронирований: #{bookings.count}"
bookings.each do |booking|
  log_info "  - #{booking.booking_date} #{booking.start_time} (статус: #{booking.status}, категория: #{booking.service_category&.name})"
end

# 2. Тестируем логику проверки доступности времени
log_section("ТЕСТИРОВАНИЕ ЛОГИКИ ДОСТУПНОСТИ ВРЕМЕНИ")

test_date = Date.current + 1.day
test_time = "10:00"
category_id = posts.first&.service_category_id

if category_id
  log_info "Тестируем доступность на #{test_date} в #{test_time} для категории #{category_id}"
  
  # Получаем доступные слоты
  available_slots = DynamicAvailabilityService.available_slots_for_category(
    service_point.id, 
    test_date, 
    category_id
  )
  
  log_info "Найдено доступных слотов: #{available_slots.count}"
  
  # Проверяем конкретное время
  slot_10_00 = available_slots.find { |slot| slot[:time] == test_time }
  if slot_10_00
    log_success "Слот #{test_time} доступен: #{slot_10_00[:available_posts]} из #{slot_10_00[:total_posts]} постов свободно"
  else
    log_warning "Слот #{test_time} недоступен"
  end
end

# 3. Симулируем изменение расписания
log_section("СИМУЛЯЦИЯ ИЗМЕНЕНИЯ РАСПИСАНИЯ")

# Создадим тестовое бронирование
if category_id && posts.any?
  test_booking_data = {
    service_point_id: service_point.id,
    booking_date: test_date,
    start_time: "#{test_time}:00",
    end_time: "11:00:00",
    service_category_id: category_id,
    car_type_id: CarType.first&.id || 1,
    service_recipient_first_name: "Тест",
    service_recipient_last_name: "Тестович",
    service_recipient_phone: "+380501234567",
    status: 'confirmed'
  }
  
  # Проверяем, есть ли уже такое бронирование
  existing_booking = Booking.find_by(
    service_point_id: service_point.id,
    booking_date: test_date,
    start_time: "#{test_time}:00"
  )
  
  if existing_booking
    log_info "Используем существующее бронирование: ID #{existing_booking.id}"
    test_booking = existing_booking
  else
    log_info "Создаем тестовое бронирование..."
    test_booking = Booking.new(test_booking_data)
    test_booking.skip_availability_check = true  # Пропускаем проверку для теста
    test_booking.skip_notifications = true
    
    if test_booking.save
      log_success "Создано тестовое бронирование ID: #{test_booking.id}"
    else
      log_error "Ошибка создания бронирования: #{test_booking.errors.full_messages.join(', ')}"
    end
  end
  
  if test_booking&.persisted?
    # Проверяем текущую доступность
    log_info "Проверяем доступность после создания бронирования..."
    updated_slots = DynamicAvailabilityService.available_slots_for_category(
      service_point.id, 
      test_date, 
      category_id
    )
    
    updated_slot_10_00 = updated_slots.find { |slot| slot[:time] == test_time }
    if updated_slot_10_00
      log_info "После бронирования слот #{test_time}: #{updated_slot_10_00[:available_posts]} из #{updated_slot_10_00[:total_posts]} постов свободно (#{updated_slot_10_00[:bookings_count]} бронирований)"
    else
      log_warning "После бронирования слот #{test_time} стал недоступен"
    end
  end
end

# 4. Тестируем систему анализа конфликтов
log_section("ТЕСТИРОВАНИЕ СИСТЕМЫ АНАЛИЗА КОНФЛИКТОВ")

# Запускаем анализ конфликтов для сервисной точки
log_info "Запускаем анализ конфликтов для сервисной точки #{service_point.id}..."

conflicts = BookingConflictAnalysisService.new(service_point: service_point).call

log_info "Найдено конфликтов: #{conflicts.count}"
conflicts.each_with_index do |conflict, index|
  if conflict
    log_warning "Конфликт #{index + 1}: #{conflict.conflict_type} - #{conflict.conflict_reason}"
    log_info "  Бронирование: #{conflict.booking.booking_date} #{conflict.booking.start_time} (ID: #{conflict.booking.id})"
  end
end

# 5. Проверяем логику подсчета конфликтов при разном количестве постов
log_section("ТЕСТИРОВАНИЕ КОНФЛИКТОВ ЗАГРУЖЕННОСТИ")

if posts.count > 1
  log_info "Тестируем конфликты при наличии #{posts.count} постов"
  
  # Создаем несколько бронирований на одно время
  test_time_conflict = "14:00"
  
  log_info "Создаем #{posts.count + 1} бронирований на #{test_time_conflict} (больше чем постов)..."
  
  created_bookings = []
  (posts.count + 1).times do |i|
    conflict_booking = Booking.new(
      service_point_id: service_point.id,
      booking_date: test_date,
      start_time: "#{test_time_conflict}:00",
      end_time: "15:00:00",
      service_category_id: category_id,
      car_type_id: CarType.first&.id || 1,
      service_recipient_first_name: "Конфликт#{i + 1}",
      service_recipient_last_name: "Тестович",
      service_recipient_phone: "+38050123456#{i}",
      status: 'confirmed'
    )
    
    conflict_booking.skip_availability_check = true
    conflict_booking.skip_notifications = true
    
    if conflict_booking.save
      created_bookings << conflict_booking
      log_info "  Создано бронирование #{i + 1}: ID #{conflict_booking.id}"
    end
  end
  
  # Проверяем доступность после создания конфликтующих бронирований
  log_info "Проверяем доступность слота #{test_time_conflict}..."
  
  conflict_slots = DynamicAvailabilityService.available_slots_for_category(
    service_point.id, 
    test_date, 
    category_id
  )
  
  conflict_slot = conflict_slots.find { |slot| slot[:time] == test_time_conflict }
  if conflict_slot
    log_warning "Слот #{test_time_conflict}: #{conflict_slot[:available_posts]} из #{conflict_slot[:total_posts]} постов свободно (#{conflict_slot[:bookings_count]} бронирований)"
    
    if conflict_slot[:available_posts] < 0
      log_error "КОНФЛИКТ ЗАГРУЖЕННОСТИ: Бронирований больше чем постов!"
    elsif conflict_slot[:available_posts] == 0
      log_warning "Все посты заняты в это время"
    end
  else
    log_error "Слот #{test_time_conflict} полностью недоступен"
  end
  
  # Запускаем анализ конфликтов еще раз
  log_info "Повторный анализ конфликтов..."
  new_conflicts = BookingConflictAnalysisService.new(service_point: service_point).call
  
  log_info "Найдено конфликтов после создания перегрузки: #{new_conflicts.count}"
  
  # Очищаем тестовые данные
  log_info "Очищаем тестовые бронирования..."
  created_bookings.each(&:destroy)
  log_success "Тестовые бронирования удалены"
end

# 6. Проверяем логику при изменении расписания
log_section("ТЕСТИРОВАНИЕ КОНФЛИКТОВ ПРИ ИЗМЕНЕНИИ РАСПИСАНИЯ")

# Найдем пост с расписанием
test_post = posts.first
if test_post
  log_info "Тестируем изменение статуса поста #{test_post.post_number}"
  
  original_status = test_post.is_active
  log_info "Исходный статус поста: #{original_status ? 'активен' : 'неактивен'}"
  
  # Деактивируем пост
  test_post.update!(is_active: false)
  log_info "Пост деактивирован"
  
  # Проверяем доступность
  log_info "Проверяем доступность после деактивации поста..."
  
  deactivated_slots = DynamicAvailabilityService.available_slots_for_category(
    service_point.id, 
    test_date, 
    category_id
  )
  
  log_info "Доступных слотов после деактивации: #{deactivated_slots.count}"
  
  # Запускаем анализ конфликтов
  log_info "Анализ конфликтов после деактивации поста..."
  deactivation_conflicts = BookingConflictAnalysisService.new(service_point: service_point).call
  
  log_info "Конфликтов после деактивации: #{deactivation_conflicts.count}"
  
  # Восстанавливаем исходный статус
  test_post.update!(is_active: original_status)
  log_success "Статус поста восстановлен"
end

log_section("ЗАКЛЮЧЕНИЕ")

log_success "Анализ логики системы конфликтов завершен"
log_info "Система должна корректно обрабатывать:"
log_info "  1. Временные конфликты (недоступность времени)"
log_info "  2. Конфликты загруженности (больше бронирований чем постов)"
log_info "  3. Конфликты при изменении расписания/статусов"

puts "\n🎯 Рекомендации по улучшению:"
puts "   - Убедиться что система учитывает все типы конфликтов"
puts "   - Проверить правильность подсчета доступных постов"
puts "   - Валидировать логику при изменении расписаний" 