# Требования к доработке системы бронирований для MVP

## 🚨 ВЛИЯНИЕ ИНДИВИДУАЛЬНЫХ ПОСТОВ

### Критические изменения в архитектуре бронирований
С введением модели **ServicePost** (индивидуальные настройки постов) система бронирований должна:

1. **Учитывать разную длительность постов** при расчете времени
2. **Валидировать доступность конкретного поста** с его индивидуальной длительностью
3. **Правильно резервировать слоты** с учетом времени освобождения каждого поста
4. **Предлагать оптимальные слоты** на основе реального расписания постов

**Пример влияния:**
- Бронирование на 30 минут может занять Пост 1 (30 мин) полностью
- Но на Посту 2 (40 мин) останется 10 минут "простоя"
- Система должна это учитывать при рекомендациях

---

## 🎯 Текущие проблемы для решения

### 1. Проверка доступности слотов
- ❌ **ПРОБЛЕМА**: Отсутствует проверка доступности слота при создании бронирования
- ❌ **ПРОБЛЕМА**: Возможно создание нескольких бронирований на один слот
- ❌ **ПРОБЛЕМА**: Нет проверки пересечений по времени
- 🚨 **НОВАЯ ПРОБЛЕМА**: Не учитывается индивидуальная длительность постов

### 2. Автоматический расчет времени
- ❌ **ПРОБЛЕМА**: Время окончания устанавливается вручную
- ❌ **ПРОБЛЕМА**: Не учитывается длительность выбранных услуг
- ❌ **ПРОБЛЕМА**: Нет валидации соответствия времени и услуг
- 🚨 **НОВАЯ ПРОБЛЕМА**: Не учитывается время освобождения конкретного поста

### 3. Валидация временных конфликтов
- ❌ **ПРОБЛЕМА**: Отсутствует проверка пересечений с другими бронированиями
- ❌ **ПРОБЛЕМА**: Не проверяется доступность поста в указанное время
- ❌ **ПРОБЛЕМА**: Нет блокировки одновременного создания бронирований
- 🚨 **НОВАЯ ПРОБЛЕМА**: Не учитывается индивидуальное расписание каждого поста

## 🛠 Технические требования к доработке

### 1. Модель Booking - добавить валидации

```ruby
# Добавить валидации с учетом ServicePost:
validate :slot_must_be_available
validate :booking_time_matches_slot  
validate :services_fit_in_time_slot_for_post  # ОБНОВИТЬ: учет ServicePost
validate :no_conflicting_bookings_for_post    # ОБНОВИТЬ: учет ServicePost
validate :post_is_available_for_duration      # НОВОЕ: проверка поста

# Добавить коллбэки:
before_validation :calculate_end_time_from_services_and_post  # ОБНОВИТЬ
before_create :reserve_slot_for_post                        # ОБНОВИТЬ
after_destroy :release_slot_for_post                        # ОБНОВИТЬ

# Добавить методы:
def calculate_total_duration_for_post(post)  # НОВОЕ
def reserve_required_slots_for_post          # ОБНОВИТЬ
def release_reserved_slots_for_post          # ОБНОВИТЬ
def conflicts_with_other_bookings_on_post?   # НОВОЕ
def find_optimal_post_for_services           # НОВОЕ

# Добавить связи:
belongs_to :service_post, foreign_key: :post_number, primary_key: :post_number, optional: true
```

### 2. Сервис BookingManager (критическое обновление)

```ruby
class BookingManager
  # Создание бронирования с проверками постов
  def self.create_booking(params)
    # 1. Определить оптимальный пост для услуг
    # 2. Валидация доступности конкретного поста
    # 3. Расчет времени с учетом длительности поста
    # 4. Резервирование слотов для конкретного поста
    # 5. Создание бронирования
    # 6. Обработка ошибок и откат
  end
  
  # Проверка доступности с учетом постов
  def self.check_availability(service_point_id, date, start_time, services, preferred_post = nil)
    service_point = ServicePoint.find(service_point_id)
    required_duration = calculate_total_duration(services)
    
    # Найти доступные посты в указанное время
    available_posts = service_point.service_posts.active.select do |post|
      post_available_at_time?(post, date, start_time, required_duration)
    end
    
    {
      available: available_posts.any?,
      available_posts: available_posts.map(&:post_number),
      recommended_post: find_best_post_for_services(available_posts, services),
      conflicts: find_conflicts_for_time(service_point, date, start_time, required_duration)
    }
  end
  
  # Расчет времени с учетом поста
  def self.calculate_booking_duration(service_ids, post_number = nil)
    services_duration = Service.where(id: service_ids).sum(:base_duration)
    
    if post_number
      post = ServicePost.find_by(post_number: post_number)
      post_slot_duration = post&.slot_duration || 60
      
      # Время бронирования не может превышать время слота поста
      [services_duration, post_slot_duration].min
    else
      services_duration
    end
  end
  
  # Поиск оптимального поста для услуг
  def self.find_optimal_post(service_point_id, date, services, preferred_time = nil)
    service_point = ServicePoint.find(service_point_id)
    required_duration = calculate_total_duration(services)
    
    # Найти посты, которые могут выполнить услуги
    suitable_posts = service_point.service_posts.active.select do |post|
      post.slot_duration >= required_duration
    end
    
    # Найти наиболее эффективное время для каждого поста
    recommendations = suitable_posts.map do |post|
      optimal_time = find_next_available_time_for_post(post, date, preferred_time)
      efficiency = calculate_post_efficiency(post, required_duration)
      
      {
        post_number: post.post_number,
        post_name: post.name,
        optimal_time: optimal_time,
        efficiency: efficiency,
        waste_time: post.slot_duration - required_duration
      }
    end
    
    # Сортировать по эффективности (меньше простоя)
    recommendations.sort_by { |r| r[:waste_time] }
  end
  
  private
  
  def self.post_available_at_time?(post, date, start_time, duration)
    # Проверить, свободен ли пост в указанное время
    end_time = start_time + duration.minutes
    
    !ScheduleSlot.joins(:bookings)
      .where(
        slot_date: date,
        post_number: post.post_number
      )
      .where('start_time < ? AND end_time > ?', end_time, start_time)
      .exists?
  end
  
  def self.find_best_post_for_services(available_posts, services)
    required_duration = calculate_total_duration(services)
    
    # Выбрать пост с минимальным простоем
    available_posts.min_by do |post|
      post.slot_duration - required_duration
    end
  end
end
```

### 3. Модель Service - добавить длительность

```ruby
# Добавить поля в миграцию:
# - base_duration: integer (базовая длительность в минутах)
# - duration_multiplier_by_car_type: jsonb (множители по типам авто)

# Добавить методы:
def duration_for_car_type(car_type)
  base_duration * (duration_multiplier_by_car_type[car_type.to_s] || 1.0)
end

def adjusted_duration(car_type = nil)
  car_type ? duration_for_car_type(car_type) : base_duration
end

# Совместимость с постами
def fits_in_post?(service_post, car_type = nil)
  adjusted_duration(car_type) <= service_post.slot_duration
end
```

### 4. API эндпоинты для проверок (обновленные)

```
POST /api/v1/bookings/check_availability
  # Параметры: service_point_id, date, start_time, service_ids, car_type_id, preferred_post
  # Ответ: 
  {
    available: true/false, 
    available_posts: [1, 3], 
    recommended_post: 1,
    post_details: [
      {post_number: 1, available: true, efficiency: 95%, waste_time: 5},
      {post_number: 2, available: false, next_available: "10:40"},
      {post_number: 3, available: true, efficiency: 80%, waste_time: 10}
    ],
    conflicts: [], 
    suggested_times: []
  }

POST /api/v1/bookings/calculate_duration
  # Параметры: service_ids, car_type_id, post_number
  # Ответ: 
  {
    total_duration: 35, 
    services_duration: 35,
    post_slot_duration: 40,
    efficiency: 87.5,
    waste_time: 5,
    service_durations: [
      {service_id: 1, name: "Замена колес", duration: 20},
      {service_id: 2, name: "Балансировка", duration: 15}
    ]
  }

GET /api/v1/bookings/optimal_posts
  # Параметры: service_point_id, date, service_ids, preferred_time, car_type_id
  # Ответ: 
  {
    recommendations: [
      {
        post_number: 1,
        post_name: "Пост быстрого обслуживания",
        optimal_time: "10:00",
        efficiency: 95%,
        waste_time: 5,
        next_available: "10:00"
      }
    ],
    alternative_times: ["10:30", "11:00", "11:30"]
  }

GET /api/v1/service_points/:id/posts/:post_number/availability/:date
  # Ответ: расписание доступности конкретного поста
```

### 5. Улучшения контроллера бронирований

```ruby
# В BookingsController добавить:
before_action :check_slot_availability_for_post, only: [:create]
before_action :calculate_duration_for_post, only: [:create]
before_action :find_optimal_post, only: [:create]

private

def check_slot_availability_for_post
  # Проверка доступности конкретного поста
  unless BookingManager.check_availability(
    booking_params[:service_point_id],
    booking_params[:appointment_date],
    booking_params[:appointment_time],
    booking_params[:service_ids],
    booking_params[:post_number]
  )[:available]
    render json: { errors: ['Выбранный пост недоступен в указанное время'] }, status: :unprocessable_entity
  end
end

def calculate_duration_for_post
  # Автоматический расчет времени с учетом поста
  duration = BookingManager.calculate_booking_duration(
    booking_params[:service_ids],
    booking_params[:post_number]
  )
  
  @calculated_end_time = Time.parse(booking_params[:appointment_time]) + duration.minutes
end

def find_optimal_post
  # Если пост не указан, найти оптимальный
  unless booking_params[:post_number]
    optimal = BookingManager.find_optimal_post(
      booking_params[:service_point_id],
      booking_params[:appointment_date],
      Service.where(id: booking_params[:service_ids]),
      booking_params[:appointment_time]
    ).first
    
    params[:booking][:post_number] = optimal[:post_number] if optimal
  end
end

def booking_params
  params.require(:booking).permit(
    :service_point_id, :client_id, :appointment_date, :appointment_time,
    :post_number, :car_brand, :car_model, :car_year, :notes,
    service_ids: []
  )
end
```

## 📊 Приоритетность задач

### Приоритет 0 (БЛОКЕР - зависит от ServicePost):
1. **Обновление валидаций Booking** - учет индивидуальных постов
2. **BookingManager.check_availability** - проверка с учетом постов
3. **Расчет времени для постов** - calculate_duration_for_post
4. **API проверки доступности** - обновленные эндпоинты

### Приоритет 1 (критично - блокеры MVP):
1. **Резервирование слотов постов** - предотвращение двойных бронирований
2. **Автоматический расчет времени** - корректное планирование
3. **Валидация конфликтов постов** - защита от пересечений
4. **Поиск оптимального поста** - эффективное использование ресурсов

### Приоритет 2 (важно для качества):
1. Предложение альтернативных постов и времени
2. Групповое бронирование услуг на оптимальных постах
3. Валидация изменений бронирований с учетом постов
4. Аналитика эффективности использования постов

### Приоритет 3 (улучшения UX):
1. Интеллектуальные рекомендации постов и времени
2. Автоматическое переопределение при конфликтах  
3. Предварительные бронирования с резервированием постов
4. Гибкая настройка длительности услуг по постам

## 🧪 Тестирование (обновленные сценарии)

### Критические сценарии для тестирования:
1. **Одновременное создание бронирований на один пост** - race conditions
2. **Превышение времени слота поста** - валидация длительности
3. **Бронирование на пост с несовместимой длительностью** - валидация услуг
4. **Изменение бронирования с конфликтами постов** - обновление
5. **Массовое создание бронирований на разных постах** - производительность
6. **Поиск оптимального поста для комплекса услуг** - алгоритм выбора
7. **Резервирование и освобождение слотов постов** - lifecycle

### Тесты производительности:
1. Время отклика проверки доступности постов
2. Масштабирование при большом количестве постов и слотов
3. Обработка пиковых нагрузок на разные посты
4. Конкурентное создание бронирований на одном посту
5. Эффективность алгоритма поиска оптимального поста

### Новые edge cases:
1. Все посты заняты, но с разным временем освобождения
2. Услуги не помещаются ни в один пост
3. Изменение настроек поста во время активных бронирований
4. Деактивация поста с существующими бронированиями 