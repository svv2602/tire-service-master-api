# API для индивидуальных расписаний постов

## Обзор

Система поддерживает индивидуальные расписания для постов обслуживания, позволяя каждому посту иметь собственные рабочие дни и часы работы, отличные от общего расписания точки обслуживания.

## Поля модели ServicePost

### Новые поля

- `has_custom_schedule` (boolean, default: false) - флаг включения индивидуального расписания
- `working_days` (json) - рабочие дни недели в формате `{"monday": true, "tuesday": false, ...}`
- `custom_hours` (json) - часы работы в формате `{"start": "09:00", "end": "18:00"}`

### Валидации

- При `has_custom_schedule: true`:
  - `working_days` должно быть объектом с корректными днями недели (monday-sunday)
  - `custom_hours` должно содержать поля `start` и `end` в формате HH:MM
  - Время начала должно быть меньше времени окончания
  - Должен быть выбран хотя бы один рабочий день

## API Endpoints

### Создание точки с индивидуальными расписаниями постов

```http
POST /api/v1/partners/:partner_id/service_points
Content-Type: application/json
Authorization: Bearer <token>

{
  "service_point": {
    "name": "Тестовая точка",
    "address": "ул. Тестовая, 1",
    "city_id": 1,
    "contact_phone": "+380501234567",
    "service_posts_attributes": [
      {
        "name": "Обычный пост",
        "post_number": 1,
        "slot_duration": 60,
        "has_custom_schedule": false
      },
      {
        "name": "Пост с индивидуальным расписанием",
        "post_number": 2,
        "slot_duration": 30,
        "has_custom_schedule": true,
        "working_days": {
          "monday": true,
          "tuesday": false,
          "wednesday": true,
          "thursday": true,
          "friday": false,
          "saturday": false,
          "sunday": false
        },
        "custom_hours": {
          "start": "10:00",
          "end": "19:00"
        }
      }
    ]
  }
}
```

### Обновление поста с индивидуальным расписанием

```http
PATCH /api/v1/partners/:partner_id/service_points/:id
Content-Type: application/json
Authorization: Bearer <token>

{
  "service_point": {
    "service_posts_attributes": [
      {
        "id": 123,
        "has_custom_schedule": true,
        "working_days": {
          "monday": true,
          "tuesday": true,
          "wednesday": false,
          "thursday": true,
          "friday": true,
          "saturday": false,
          "sunday": false
        },
        "custom_hours": {
          "start": "09:00",
          "end": "17:00"
        }
      }
    ]
  }
}
```

### Получение данных точки с индивидуальными расписаниями

```http
GET /api/v1/service_points/:id
Authorization: Bearer <token>
```

**Ответ:**
```json
{
  "id": 1,
  "name": "Тестовая точка",
  "service_posts": [
    {
      "id": 1,
      "post_number": 1,
      "name": "Обычный пост",
      "has_custom_schedule": false,
      "working_days": null,
      "custom_hours": null,
      "working_days_list": []
    },
    {
      "id": 2,
      "post_number": 2,
      "name": "Пост с индивидуальным расписанием",
      "has_custom_schedule": true,
      "working_days": {
        "monday": true,
        "tuesday": false,
        "wednesday": true,
        "thursday": true,
        "friday": false,
        "saturday": false,
        "sunday": false
      },
      "custom_hours": {
        "start": "10:00",
        "end": "19:00"
      },
      "working_days_list": ["monday", "wednesday", "thursday"]
    }
  ]
}
```

## Методы модели ServicePost

### Проверка рабочих дней и времени

```ruby
# Проверяет, работает ли пост в указанный день недели
service_post.working_on_day?('monday') # => true/false

# Получает время начала/окончания работы для дня
service_post.start_time_for_day('monday') # => "10:00"
service_post.end_time_for_day('monday')   # => "19:00"

# Проверяет доступность в конкретное время
service_post.available_at_time?(DateTime.parse('2024-12-09 15:00')) # => true/false

# Получает список рабочих дней
service_post.working_days_list # => ["monday", "wednesday", "thursday"]
```

### Скоупы

```ruby
# Получить только посты с индивидуальными расписаниями
ServicePost.with_custom_schedule

# Получить активные посты
ServicePost.active

# Получить посты для конкретной точки
ServicePost.for_service_point(service_point_id)
```

## Интеграция с ScheduleManager

ScheduleManager автоматически учитывает индивидуальные расписания постов при генерации слотов:

```ruby
# Генерирует слоты с учетом индивидуальных расписаний
ScheduleManager.generate_slots_for_date(service_point, date)

# Генерирует слоты для конкретного поста
ScheduleManager.generate_slots_for_post(service_post, date, start_time, end_time)
```

## Примеры использования

### Создание поста с индивидуальным расписанием

```ruby
service_post = ServicePost.create!(
  service_point: service_point,
  name: "Специальный пост",
  post_number: 3,
  slot_duration: 45,
  has_custom_schedule: true,
  working_days: {
    'monday' => true,
    'wednesday' => true,
    'friday' => true
  },
  custom_hours: {
    'start' => '08:00',
    'end' => '16:00'
  }
)
```

### Проверка доступности поста

```ruby
# Проверка работы в понедельник
if service_post.working_on_day?('monday')
  puts "Пост работает в понедельник с #{service_post.start_time_for_day('monday')} до #{service_post.end_time_for_day('monday')}"
end

# Проверка доступности в конкретное время
datetime = DateTime.parse('2024-12-09 14:30') # понедельник
if service_post.available_at_time?(datetime)
  puts "Пост доступен в указанное время"
end
```

## Ошибки валидации

При некорректных данных API возвращает статус 422 с описанием ошибок:

```json
{
  "errors": {
    "service_posts.working_days": ["должен быть выбран хотя бы один рабочий день"],
    "service_posts.custom_hours": ["время начала должно быть меньше времени окончания"]
  }
}
```

## Тестирование

Созданы комплексные тесты:
- `spec/models/service_post_custom_schedule_spec.rb` - тесты модели
- `spec/serializers/service_post_serializer_spec.rb` - тесты сериализатора
- `spec/services/schedule_manager_custom_schedule_spec.rb` - тесты ScheduleManager
- `spec/requests/api/v1/service_points_custom_posts_spec.rb` - тесты API

Запуск всех тестов:
```bash
bundle exec rspec spec/models/service_post_custom_schedule_spec.rb spec/serializers/service_post_serializer_spec.rb spec/services/schedule_manager_custom_schedule_spec.rb spec/requests/api/v1/service_points_custom_posts_spec.rb
```