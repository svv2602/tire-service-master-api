# 🎯 ИСПРАВЛЕНО: Проблема валидации доступности времени бронирования с категориями услуг

## Проблема
При создании гостевых бронирований через фронтенд возникала ошибка 422 "Время недоступно: Нет доступного слота в указанное время", хотя время было реально доступно.

### Симптомы
```javascript
// Фронтенд отправлял корректные данные:
{
  "booking": {
    "service_point_id": 6,
    "service_category_id": 1,
    "booking_date": "2025-07-03",
    "start_time": "12:00",
    // ...
  }
}

// Но получал ошибку 422:
{
  "error": "Не удалось создать запись",
  "details": ["Время недоступно: Нет доступного слота в указанное время"]
}
```

### Диагностика
1. **API проверка доступности работала** - DynamicAvailabilityService.check_availability_at_time возвращал `available: true`
2. **Сервисная точка ID=6 имела 3 активных поста** для категории 1
3. **43 доступных слота** на выбранную дату
4. **Время 12:00 было свободно**

## Корневая причина
Несоответствие в валидации между контроллером и моделью:

### В контроллере (ClientBookingsController#perform_availability_check)
```ruby
# ✅ ПРАВИЛЬНО: передается category_id
availability = DynamicAvailabilityService.check_availability_at_time(
  booking_data[:service_point_id].to_i,
  Date.parse(booking_data[:booking_date]),
  Time.parse("#{booking_data[:booking_date]} #{booking_data[:start_time]}"),
  calculate_duration_minutes,
  exclude_booking_id: nil,
  category_id: booking_data[:service_category_id]  # ✅ Передается
)
```

### В модели (Booking#booking_time_available)
```ruby
# ❌ НЕПРАВИЛЬНО: НЕ передавался category_id
availability = DynamicAvailabilityService.check_availability_at_time(
  service_point_id,
  booking_date,
  start_datetime,
  total_duration_minutes,
  exclude_booking_id: persisted? ? id : nil
  # ❌ category_id НЕ передавался!
)
```

## Решение
Добавлен параметр `category_id` в валидацию модели Booking:

```ruby
# ✅ ИСПРАВЛЕНО
def booking_time_available
  return if skip_availability_check
  return unless service_point_id && booking_date && start_time && end_time
  
  # Преобразуем время в правильный формат для проверки
  start_datetime = if start_time.is_a?(String)
    Time.parse("#{booking_date} #{start_time}")
  else
    Time.parse("#{booking_date} #{start_time.strftime('%H:%M')}")
  end
  
  # Проверяем что время в рабочих часах с учетом категории услуг
  availability = DynamicAvailabilityService.check_availability_at_time(
    service_point_id,
    booking_date,
    start_datetime,
    total_duration_minutes,
    exclude_booking_id: persisted? ? id : nil,
    category_id: service_category_id  # ✅ ДОБАВЛЕНО
  )
  
  unless availability[:available]
    errors.add(:base, "Время недоступно: #{availability[:reason]}")
  end
  
  # Остальная логика...
end
```

## Тестирование
### ✅ Rails консоль
```ruby
booking = Booking.new({
  service_point_id: 6,
  service_category_id: 1,
  booking_date: '2025-07-03',
  start_time: '12:00',
  end_time: '13:00',
  service_recipient_first_name: 'Тестовый',
  service_recipient_last_name: 'Админ',
  service_recipient_phone: '+380672220000',
  service_recipient_email: 'admin@test.com',
  car_type_id: 8
})

booking.save  # ✅ Успешно создано с ID=1
```

### ✅ API тестирование
```bash
curl -X POST http://localhost:8000/api/v1/client_bookings \
  -H "Content-Type: application/json" \
  -d '{"booking": {...}, "car": {...}}'

# ✅ Результат: HTTP 201 Created, ID=2
```

## Результат
- ✅ Гостевые бронирования создаются без ошибок
- ✅ Валидация учитывает категории услуг
- ✅ Согласованность между контроллером и моделью
- ✅ API возвращает корректные ответы
- ✅ Фронтенд может успешно создавать бронирования

## Файлы изменены
- `app/models/booking.rb` - добавлен параметр `category_id` в валидацию `booking_time_available`

## Коммит
Готов к коммиту в tire-service-master-api репозиторий. 