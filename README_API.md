# API сервиса "Твоя шина"

## Общая информация

API предоставляет доступ к функциональности сервиса "Твоя шина" для управления бронированиями шиномонтажных услуг.

- **Базовый URL**: `http://localhost:8000/api/v1`
- **Формат данных**: JSON
- **Аутентификация**: JWT token в заголовке `Authorization: Bearer <token>`

## Запуск API

Для запуска API в режиме разработки выполните команду:

```bash
cd api
./start_api.sh
```

Сервер будет доступен по адресу: `http://localhost:8000`

## Авторизация

### Вход в систему

```
POST /api/v1/auth/login
```

**Тело запроса**:
```json
{
  "email": "admin@example.com",
  "password": "password"
}
```

**Ответ**:
```json
{
  "auth_token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "email": "admin@example.com",
    "first_name": "Admin",
    "last_name": "User",
    "role": "admin"
  }
}
```

### Регистрация клиента

```
POST /api/v1/register
```

**Тело запроса**:
```json
{
  "email": "client@example.com",
  "password": "password",
  "password_confirmation": "password",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+380501234567"
}
```

**Ответ**:
```json
{
  "auth_token": "eyJhbGciOiJIUzI1NiJ9...",
  "message": "Account created successfully"
}
```

## Партнеры

### Получение списка партнеров

```
GET /api/v1/partners
```

### Создание тестового партнера

```
POST /api/v1/partners/create_test
```

### Получение информации о партнере

```
GET /api/v1/partners/:id
```

### Создание партнера

```
POST /api/v1/partners
```

**Тело запроса**:
```json
{
  "user": {
    "email": "partner@example.com",
    "password": "password",
    "password_confirmation": "password",
    "first_name": "Partner",
    "last_name": "User",
    "phone": "+380501234567"
  },
  "partner": {
    "company_name": "AutoService LLC",
    "company_description": "Professional tire service",
    "contact_person": "John Smith",
    "logo_url": "https://example.com/logo.png",
    "website": "https://autoservice.com",
    "tax_number": "12345678",
    "legal_address": "123 Main St, Kiev, Ukraine",
    "region_id": 1,
    "city_id": 1
  }
}
```

**Обязательные поля**:
- `user.email` - email пользователя (должен быть уникальным)
- `user.first_name` - имя пользователя
- `user.last_name` - фамилия пользователя
- `user.phone` - телефон пользователя
- `partner.company_name` - название компании
- `partner.contact_person` - контактное лицо
- `partner.legal_address` - юридический адрес
- `partner.region_id` - ID региона
- `partner.city_id` - ID города

**Необязательные поля**:
- `user.password` - пароль (если не указан, будет сгенерирован автоматически)
- `partner.company_description` - описание компании
- `partner.logo_url` - URL логотипа
- `partner.website` - веб-сайт компании
- `partner.tax_number` - налоговый номер (если указан, должен быть уникальным)

## Менеджеры

### Получение списка менеджеров партнера

```
GET /api/v1/partners/:partner_id/managers
```

### Создание тестового менеджера

```
POST /api/v1/partners/:partner_id/managers/create_test
```

### Создание менеджера

```
POST /api/v1/partners/:partner_id/managers
```

**Тело запроса**:
```json
{
  "user": {
    "email": "manager@example.com",
    "password": "password",
    "password_confirmation": "password",
    "first_name": "Manager",
    "last_name": "User",
    "phone": "+380501234567"
  },
  "manager": {
    "position": "Service Manager",
    "access_level": 1
  },
  "service_point_ids": [1, 2, 3]
}
```

## Сервисные точки

### Получение списка сервисных точек

```
GET /api/v1/service_points
```

### Получение сервисных точек партнера

```
GET /api/v1/partners/:partner_id/service_points
```

### Получение ближайших сервисных точек

```
GET /api/v1/service_points/nearby?latitude=50.45&longitude=30.52&distance=10
```

### Создание сервисной точки

```
POST /api/v1/partners/:partner_id/service_points
```

**Тело запроса**:
```json
{
  "name": "AutoService Central",
  "description": "Our central location with 5 posts",
  "address": "123 Main St, Kiev",
  "city_id": 1,
  "latitude": 50.45,
  "longitude": 30.52,
  "contact_phone": "+380501234567",
  "post_count": 5,
  "default_slot_duration": 60,
  "status_id": 1
}
```

## Услуги сервисной точки

### Получение услуг сервисной точки

```
GET /api/v1/service_points/:service_point_id/services
```

### Добавление услуги к сервисной точке

```
POST /api/v1/service_points/:service_point_id/services
```

**Тело запроса**:
```json
{
  "service_id": 1
}
```

### Удаление услуги из сервисной точки

```
DELETE /api/v1/service_points/:service_point_id/services/:service_id
```

## Расписание

### Получение расписания на день

```
GET /api/v1/schedule/:service_point_id/:date
```

### Получение расписания на период

```
GET /api/v1/schedule/:service_point_id/:from_date/:to_date
```

### Генерация расписания на день

```
POST /api/v1/schedule/generate_for_date/:service_point_id/:date
```

### Генерация расписания на период

```
POST /api/v1/schedule/generate_for_period/:service_point_id/:from_date/:to_date
```

## Бронирования

### Получение списка бронирований клиента

```
GET /api/v1/clients/:client_id/bookings
```

### Получение списка бронирований сервисной точки

```
GET /api/v1/service_points/:service_point_id/bookings
```

### Создание бронирования

```
POST /api/v1/clients/:client_id/bookings
```

**Тело запроса**:
```json
{
  "booking": {
    "service_point_id": 1,
    "car_id": 1,
    "booking_date": "2023-10-01",
    "start_time": "10:00",
    "end_time": "11:00",
    "notes": "Please check the pressure"
  },
  "services": [
    {
      "service_id": 1,
      "quantity": 4
    },
    {
      "service_id": 2,
      "quantity": 1
    }
  ]
}
```

### Подтверждение бронирования

```
POST /api/v1/bookings/:id/confirm
```

### Отмена бронирования

```
POST /api/v1/bookings/:id/cancel
```

**Тело запроса**:
```json
{
  "cancellation_reason_id": 1,
  "comment": "Customer requested cancellation"
}
```

### Завершение бронирования

```
POST /api/v1/bookings/:id/complete
```

## Тестовые данные

### Генерация полного набора тестовых данных

```
GET /api/v1/tests/generate_data
```

### Создание тестового клиента

```
POST /api/v1/tests/create_test_client
```

### Создание тестового партнера

```
POST /api/v1/tests/create_test_partner
```

### Создание тестовой сервисной точки

```
POST /api/v1/tests/create_test_service_point
```

**Тело запроса**:
```json
{
  "partner_id": 1
}
```

### Создание тестового бронирования

```
POST /api/v1/tests/create_test_booking
```

**Тело запроса**:
```json
{
  "client_id": 1,
  "service_point_id": 1
}
```

## Справочники

### Регионы

#### Получение списка регионов

```
GET /api/v1/regions
```

**Параметры запроса** (необязательные):
- `search` - поиск по названию региона
- `is_active` - фильтрация по статусу активности (true/false)
- `page` - номер страницы для пагинации (по умолчанию: 1)
- `per_page` - количество элементов на странице (по умолчанию: 25)

**Ответ**:
```json
{
  "data": [
    {
      "id": 1,
      "name": "Киевская область",
      "code": "KY",
      "is_active": true,
      "cities_count": 15,
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z",
      "cities": [
        {
          "id": 1,
          "name": "Киев"
        }
      ]
    }
  ],
  "pagination": {
    "total_count": 25,
    "total_pages": 1,
    "current_page": 1,
    "per_page": 25
  }
}
```

#### Получение региона по ID

```
GET /api/v1/regions/:id
```

**Ответ**:
```json
{
  "id": 1,
  "name": "Киевская область",
  "code": "KY",
  "is_active": true,
  "cities_count": 15,
  "created_at": "2024-01-01T00:00:00.000Z",
  "updated_at": "2024-01-01T00:00:00.000Z",
  "cities": [
    {
      "id": 1,
      "name": "Киев"
    }
  ]
}
```

#### Создание региона (требует аутентификации администратора)

```
POST /api/v1/regions
```

**Тело запроса**:
```json
{
  "region": {
    "name": "Новая область",
    "code": "NO",
    "is_active": true
  }
}
```

#### Обновление региона (требует аутентификации администратора)

```
PUT /api/v1/regions/:id
```

**Тело запроса**:
```json
{
  "region": {
    "name": "Обновленное название",
    "code": "ON",
    "is_active": false
  }
}
```

#### Удаление региона (требует аутентификации администратора)

```
DELETE /api/v1/regions/:id
```

**Примечание**: Регион можно удалить только если в нем нет городов.

### Города

#### Получение списка городов

```
GET /api/v1/cities
```

#### Получение городов региона

```
GET /api/v1/cities?region_id=:region_id
```