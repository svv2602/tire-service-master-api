# 📡 API Endpoints для клиентской функциональности

> **Версия:** 1.0.0  
> **Обновлено:** 2024-12-19  
> **Базовый URL:** `http://localhost:8000/api/v1`

## 🕐 Система доступности

### 1. Получение доступных временных слотов

**Endpoint:** `GET /api/v1/availability/:service_point_id/:date`

**Описание:** Возвращает список доступных временных слотов для записи на указанную дату.

**Параметры:**
- `service_point_id` (path) - ID сервисной точки
- `date` (path) - Дата в формате YYYY-MM-DD

**Пример запроса:**
```bash
GET /api/v1/availability/1/2025-06-10
```

**Пример ответа:**
```json
{
  "service_point_id": 1,
  "service_point_name": "ШиноСервіс Експрес на Хрещатику",
  "date": "2025-06-10",
  "is_working_day": true,
  "available_slots": [
    {
      "time": "09:30",
      "available_posts": 4,
      "total_posts": 4,
      "status": "available"
    },
    {
      "time": "09:45",
      "available_posts": 4,
      "total_posts": 4,
      "status": "available"
    }
  ],
  "total_slots": 34
}
```

**Особенности:**
- Автоматически фильтрует прошедшее время для текущего дня
- Показывает только рабочие дни (пн-сб 9:00-18:00)
- Интервал слотов: 15 минут
- Для выходных дней возвращает `is_working_day: false` и пустой массив слотов

---

### 2. Проверка доступности конкретного времени

**Endpoint:** `POST /api/v1/bookings/check_availability`

**Описание:** Проверяет доступность конкретного времени перед созданием записи.

**Тело запроса:**
```json
{
  "service_point_id": 1,
  "date": "2025-06-10",
  "time": "10:00",
  "duration_minutes": 60
}
```

**Пример ответа (доступно):**
```json
{
  "service_point_id": 1,
  "service_point_name": "ШиноСервіс Експрес на Хрещатику",
  "date": "2025-06-10",
  "time": "10:00",
  "available": true,
  "total_posts": 4,
  "occupied_posts": 0
}
```

**Пример ответа (недоступно):**
```json
{
  "service_point_id": 1,
  "service_point_name": "ШиноСервіс Експрес на Хрещатику",
  "date": "2025-06-10",
  "time": "10:00",
  "available": false,
  "reason": "Все посты заняты в 10:00"
}
```

**Валидация:**
- Проверяет, что время не в прошлом
- Проверяет рабочие часы сервисной точки
- Проверяет пересечения с существующими записями
- Проверяет достаточность времени до закрытия

---

## 🏢 Сервисные точки

### 3. Список сервисных точек (планируется)

**Endpoint:** `GET /api/v1/service_points?city=:city_name`

**Статус:** 📝 Планируется в фазе 1.2

---

### 4. Детали сервисной точки (планируется)

**Endpoint:** `GET /api/v1/service_points/:id/details`

**Статус:** 📝 Планируется в фазе 1.2

---

## 📋 Управление записями

### 5. Создание записи (планируется)

**Endpoint:** `POST /api/v1/clients/:client_id/bookings`

**Статус:** 📝 Планируется в фазе 1.3

---

## 🔧 Тестирование

### RSpec тесты
Все endpoints покрыты автоматическими тестами:

```bash
# Запуск всех тестов для availability контроллера
bundle exec rspec spec/requests/api/v1/availability_spec.rb

# Запуск конкретного теста
bundle exec rspec spec/requests/api/v1/availability_spec.rb:628
```

**Статистика тестов:**
- Общее количество тестов: 28
- Покрыто сценариев: 100%
- Тесты включают: валидацию параметров, обработку ошибок, рабочие/нерабочие дни, фильтрацию прошедшего времени

## 📚 Swagger документация

API endpoints задокументированы в Swagger:

**URL:** `http://localhost:8000/api-docs/index.html`

**Тег:** `Availability` - Проверка доступности и получение временных слотов

**Файлы документации:**
- `swagger/v1/swagger.yaml` - Основная документация
- `public/api-docs/v1/swagger.yaml` - Публичная версия

## 🚀 Статус разработки

✅ **Завершено:**
- Создание API endpoints
- Интеграция с DynamicAvailabilityService
- Полное покрытие тестами (28 тестов)
- Swagger документация
- Валидация параметров и обработка ошибок
- Фильтрация прошедшего времени
- Поддержка рабочих/нерабочих дней

📋 **Готово к использованию фронтенд-командой**

## 🧪 Тестирование

### Примеры curl команд

```bash
# Получить доступные слоты на завтра
curl -X GET "http://localhost:8000/api/v1/availability/1/2025-06-10" | jq

# Проверить доступность времени
curl -X POST "http://localhost:8000/api/v1/bookings/check_availability" \
  -H "Content-Type: application/json" \
  -d '{"service_point_id": 1, "date": "2025-06-10", "time": "10:00", "duration_minutes": 60}' | jq

# Проверить выходной день
curl -X GET "http://localhost:8000/api/v1/availability/1/2025-06-08" | jq
```

### Тестовые данные

В системе созданы тестовые сервисные точки:
- **ID 1:** ШиноСервіс Експрес на Хрещатику (4 поста)
- **ID 2:** ШиноСервіс Експрес на Оболоні (3 поста)
- **ID 3:** АвтоШина Плюс центр (5 постов)
- **ID 4:** АвтоШина Плюс на Сихові (2 поста)
- **ID 5:** ШинМайстер Одеса (4 поста)

---

## 📝 Следующие шаги

1. **Фаза 1.2:** Реализация поиска сервисных точек по городу
2. **Фаза 1.3:** Создание и управление записями
3. **Фаза 1.4:** Frontend API клиенты с RTK Query
4. **Фаза 1.5:** TypeScript типизация

**Готово к интеграции:** Система доступности полностью готова для подключения фронтенда.

## 🔍 **Поиск сервисных точек**

### **1. Поиск сервисных точек по городу**

```http
GET /api/v1/service_points/search
```

**Параметры запроса:**
- `city` (string, опционально): Название города для поиска
- `query` (string, опционально): Поиск по названию или адресу точки
- `latitude` (float, опционально): Широта для расчета расстояния
- `longitude` (float, опционально): Долгота для расчета расстояния

**Примеры запросов:**
```bash
# Поиск по городу
curl "http://localhost:8000/api/v1/service_points/search?city=Київ"

# Поиск с фильтром по названию
curl "http://localhost:8000/api/v1/service_points/search?city=Київ&query=Экспресс"

# Поиск всех доступных точек
curl "http://localhost:8000/api/v1/service_points/search"

# Поиск с геолокацией
curl "http://localhost:8000/api/v1/service_points/search?latitude=50.45&longitude=30.52"
```

**Ответ (200 OK):**
```json
{
  "data": [
    {
      "id": 29,
      "name": "ШиноСервіс Експрес на Хрещатику",
      "address": "вул. Хрещатик, 22",
      "city": {
        "id": 1,
        "name": "Київ",
        "region": "Київська область"
      },
      "partner": {
        "id": 29,
        "name": "ШиноСервис Экспресс"
      },
      "contact_phone": "+380 67 123 45 67",
      "average_rating": 4.5,
      "reviews_count": 15,
      "posts_count": 4,
      "can_accept_bookings": true,
      "work_status": "Работает",
      "distance": 2.5
    }
  ],
  "total": 1,
  "city_found": true
}
```

**Особенности:**
- ✅ Возвращает только **активные** точки с статусом **"working"**
- ✅ Поиск по городу **регистронезависимый**
- ✅ Поддержка фильтрации по названию/адресу
- ✅ Сортировка по рейтингу (лучшие сначала)
- ✅ Расчет расстояния при указании координат

---

### **2. Детальная информация о сервисной точке**

```http
GET /api/v1/service_points/{id}/client_details
```

**Параметры:**
- `id` (integer): ID сервисной точки

**Пример запроса:**
```bash
curl "http://localhost:8000/api/v1/service_points/29/client_details"
```

**Ответ (200 OK):**
```json
{
  "id": 29,
  "name": "ШиноСервіс Експрес на Хрещатику",
  "description": "Повний спектр послуг з шиномонтажу та балансування коліс",
  "address": "вул. Хрещатик, 22",
  "city": {
    "id": 1,
    "name": "Київ",
    "region": "Київська область"
  },
  "partner": {
    "id": 29,
    "name": "ШиноСервис Экспресс"
  },
  "contact_phone": "+380 67 123 45 67",
  "latitude": "50.450001",
  "longitude": "30.523333",
  "average_rating": 4.5,
  "reviews_count": 15,
  "total_clients_served": 156,
  "posts_count": 4,
  "can_accept_bookings": true,
  "work_status": "Работает",
  "is_working_today": true,
  "amenities": [
    {
      "id": 1,
      "name": "Wi-Fi",
      "icon": "wifi"
    }
  ],
  "photos": [
    {
      "id": 1,
      "url": "https://example.com/photo1.jpg",
      "description": "Главный вход"
    }
  ],
  "services_available": [
    {
      "id": 1,
      "name": "Замена колеса",
      "category": "Шиномонтаж"
    }
  ],
  "recent_reviews": [
    {
      "id": 1,
      "rating": 5,
      "comment": "Отличный сервис!",
      "created_at": "15.01.2025",
      "client_name": "Иван"
    }
  ]
}
```

**Ошибки:**
```json
// 403 - Точка недоступна для записи
{
  "error": "Сервисная точка недоступна для записи",
  "reason": "Техническое обслуживание"
}

// 404 - Точка не найдена
{
  "error": "Service point not found"
}
```

**Особенности:**
- ✅ Доступ только к точкам, которые **могут принимать записи**
- ✅ Полная информация включая удобства, фотографии, услуги
- ✅ Последние 3 отзыва клиентов
- ✅ Информация о работе сегодня
- ❌ Заблокированный доступ к неактивным точкам (403 Forbidden)

---

## 📊 **Статистика использования**

**Статус реализации Фазы 1.2:**
- ✅ `GET /service_points/search` - поиск по городу
- ✅ `GET /service_points/{id}/client_details` - детальная информация  
- ✅ Фильтрация только активных точек
- ✅ Поддержка геолокации
- ✅ Swagger документация
- ✅ Полное покрытие тестами

**Тестирование:**
```bash
# Запуск тестов клиентских endpoints
bundle exec rspec spec/requests/api/v1/service_points_client_spec.rb -v

# Проверка Swagger документации
curl http://localhost:8000/api-docs
``` 