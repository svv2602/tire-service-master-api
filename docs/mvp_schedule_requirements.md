# Требования к системе расписания для MVP

## 🚨 КРИТИЧЕСКИЕ ИЗМЕНЕНИЯ В АРХИТЕКТУРЕ

### Индивидуальные настройки постов обслуживания
**ПРОБЛЕМА**: Текущая система использует единую длительность слота для всех постов, но в реальности:
- Пост 1: 30 минут на обслуживание
- Пост 2: 40 минут на обслуживание  
- Пост 3: 30 минут на обслуживание

**РЕЗУЛЬТАТ**: Неправильное расписание доступности:
```
9:00 — 3 поста доступны
9:30 — 2 поста (пост 1,3 освободились, пост 2 еще занят)
9:40 — 1 пост (пост 2 освободился)
10:00 — 2 поста (посты 1,3 снова доступны)
```

**РЕШЕНИЕ**: Создать модель ServicePost с индивидуальными настройками каждого поста.

---

## 🎯 Основные функции

### 1. Автоматическая генерация слотов
- ✅ Генерация слотов на основе шаблонов расписания по дням недели
- ✅ Поддержка исключений (праздники, особые дни)
- ✅ Учет количества постов обслуживания
- 🚨 **КРИТИЧНО**: Генерация слотов с индивидуальной длительностью для каждого поста
- 🔧 **ДОРАБОТАТЬ**: Автоматическое планирование на будущие даты (rolling schedule)

### 2. Валидация доступности слотов
- ✅ Проверка статуса слота (доступен/занят)
- ✅ Связь слотов с бронированиями
- 🚨 **КРИТИЧНО**: Проверка доступности с учетом индивидуальных постов
- 🔧 **ДОБАВИТЬ**: Резервирование слотов на время оформления бронирования
- 🔧 **ДОБАВИТЬ**: Автоматическое освобождение просроченных резерваций

### 3. Расчет длительности услуг
- ✅ Базовая длительность слота для сервисной точки
- 🚨 **КРИТИЧНО**: Учет индивидуальной длительности каждого поста
- 🔧 **ДОБАВИТЬ**: Автоматический расчет времени на основе выбранных услуг
- 🔧 **ДОБАВИТЬ**: Возможность создания многослотовых бронирований

### 4. Блокировка конфликтных бронирований
- ✅ Уникальный индекс на слот
- 🔧 **ДОБАВИТЬ**: Проверка пересечений по времени
- 🔧 **ДОБАВИТЬ**: Блокировка одновременного бронирования одного слота

## 🛠 Технические требования к доработке

### 0. Модель ServicePost (КРИТИЧНО)
```ruby
# Новая модель для индивидуальных настроек постов
class ServicePost < ApplicationRecord
  belongs_to :service_point
  has_many :schedule_slots, foreign_key: :post_number, primary_key: :post_number
  
  validates :post_number, presence: true, 
    uniqueness: { scope: :service_point_id }
  validates :slot_duration, presence: true, 
    numericality: { greater_than: 0, less_than_or_equal_to: 480 }
  validates :name, length: { maximum: 255 }
  
  scope :active, -> { where(is_active: true) }
  scope :by_post_number, ->(number) { where(post_number: number) }
end

# Поля для миграции:
# - service_point_id: bigint
# - post_number: integer
# - name: string (optional)
# - slot_duration: integer (в минутах)
# - is_active: boolean
# - description: text (optional)
```

### 1. Модель ScheduleSlot (обновить)
```ruby
# Добавить поля:
# - reserved_until: datetime (до какого времени зарезервирован)
# - estimated_duration: integer (расчетная длительность в минутах)
# - booking_count: integer (количество связанных бронирований)

# Добавить методы:
# - reserve_for_minutes(minutes)
# - release_reservation
# - calculate_duration_for_services(service_ids)

# Обновить связи:
belongs_to :service_post, foreign_key: :post_number, primary_key: :post_number, optional: true
```

### 2. Обновить модель ServicePoint
```ruby
class ServicePoint < ApplicationRecord
  has_many :service_posts, dependent: :destroy
  has_many :schedule_slots, dependent: :destroy
  
  # Удалить: post_count, default_slot_duration
  
  def posts_count
    service_posts.active.count
  end
  
  def available_at_time(date, time)
    # Возвращает количество доступных постов в указанное время
    occupied_posts = schedule_slots
      .joins(:bookings)
      .where(slot_date: date)
      .where('start_time <= ? AND end_time > ?', time, time)
      .pluck(:post_number)
      
    service_posts.active.where.not(post_number: occupied_posts).count
  end
end
```

### 3. Сервис ScheduleManager (критическое обновление)
```ruby
class ScheduleManager
  # Генерация слотов с учетом индивидуальных настроек постов
  def self.generate_slots_from_template(service_point, date, template)
    delete_unused_slots(service_point.id, date)
    
    start_time = template.opening_time
    end_time = template.closing_time
    
    # Для каждого поста генерируем слоты с его индивидуальной длительностью
    service_point.service_posts.active.each do |post|
      generate_slots_for_post(service_point, date, post, start_time, end_time)
    end
  end
  
  # Новые методы:
  # - generate_rolling_schedule(service_point_id, days_ahead = 30)
  # - find_available_slots_for_duration(service_point_id, date, duration_minutes)
  # - reserve_slot_temporarily(slot_id, minutes = 15)
  # - cleanup_expired_reservations
  
  private
  
  def self.generate_slots_for_post(service_point, date, post, start_time, end_time)
    current_time = start_time
    slot_duration = post.slot_duration
    
    while current_time + slot_duration.minutes <= end_time
      slot_end_time = current_time + slot_duration.minutes
      
      # Создаем слот только если его еще нет
      unless ScheduleSlot.exists?(
        service_point_id: service_point.id,
        slot_date: date,
        start_time: current_time,
        end_time: slot_end_time,
        post_number: post.post_number
      )
        ScheduleSlot.create!(
          service_point_id: service_point.id,
          slot_date: date,
          start_time: current_time,
          end_time: slot_end_time,
          post_number: post.post_number,
          is_available: true
        )
      end
      
      # Следующий слот для этого поста
      current_time = slot_end_time
    end
  end
end
```

### 4. API эндпоинты
```
# Управление постами (КРИТИЧНО)
GET /api/v1/service_points/:service_point_id/posts
POST /api/v1/service_points/:service_point_id/posts
PUT /api/v1/service_points/:service_point_id/posts/:id
DELETE /api/v1/service_points/:service_point_id/posts/:id

# Детализированная доступность (НОВОЕ)
GET /api/v1/service_points/:id/availability/:date/by_posts
  # Ответ: availability по времени с детализацией по постам

# Существующие эндпоинты (обновить)
POST /api/v1/schedule/reserve_slot/:slot_id
DELETE /api/v1/schedule/release_reservation/:slot_id
GET /api/v1/schedule/available_slots_for_duration/:service_point_id/:date
GET /api/v1/schedule/calculate_duration (с параметрами service_ids)
```

### 5. Background Jobs
```ruby
# Обновить существующие:
# - RollingScheduleGeneratorJob (учет ServicePost)
# - ExpiredReservationCleanupJob (очистка резерваций)
# - SlotAvailabilityNotificationJob (уведомления о появлении свободных слотов)

# Новые:
# - ServicePostMigrationJob (миграция существующих данных)
# - ScheduleRegenerationJob (перегенерация после изменения постов)
```

## 📊 Приоритетность задач

### Приоритет 0 (БЛОКЕР MVP):
1. **Создание модели ServicePost** - основа новой архитектуры
2. **Миграция существующих данных** - перенос постов из ServicePoint
3. **Обновление ScheduleManager** - генерация с индивидуальными настройками
4. **API управления постами** - CRUD операции

### Приоритет 1 (критично для MVP):
1. Резервирование слотов на время оформления
2. Автоматический расчет длительности по услугам
3. Проверка временных конфликтов
4. Генерация расписания на будущие даты

### Приоритет 2 (важно):
1. Многослотовые бронирования
2. Оптимизация слотов по загрузке
3. Уведомления о доступности

### Приоритет 3 (желательно):
1. Интеллектуальное планирование
2. Аналитика использования слотов
3. Гибкая настройка длительности слотов

## 🚨 Критические изменения в архитектуре

### Что меняется:
1. **ServicePoint** теряет поля `post_count` и `default_slot_duration`
2. **ScheduleSlot** получает связь с `ServicePost` 
3. **ScheduleManager** генерирует слоты для каждого поста отдельно
4. **Все API** должны учитывать индивидуальные настройки постов

### План миграции:
1. Создать модель ServicePost
2. Заполнить данными из существующих ServicePoint
3. Обновить ScheduleManager
4. Перегенерировать все существующие слоты
5. Удалить старые поля из ServicePoint

### Риски:
- Сложность миграции без downtime
- Производительность генерации слотов
- Совместимость с существующими бронированиями 