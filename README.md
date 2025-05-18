# Твоя шина API

Бэкенд API для мобильного приложения "Твоя шина" - сервиса для управления шиномонтажными услугами, записи клиентов на шиномонтаж и администрирования сервисных точек.

## Тестовое покрытие

### Модели
- ✅ Booking
- ✅ BookingService
- ✅ CarBrand
- ✅ CarModel
- ✅ ClientCar
- ✅ Client
- ✅ PaymentStatus
- ✅ CancellationReason
- ✅ ServicePoint
- ✅ Review
- ✅ Service

### Контроллеры
- ✅ BookingsController
- ✅ ClientsController
- ✅ ServicePointsController
- ✅ ServicePointPhotosController

### Политики
- ✅ BookingPolicy
- ✅ ClientPolicy
- ✅ ServicePointPolicy

### Swagger документация
- ✅ Bookings API
- ✅ Clients API
- ✅ Service Points API
- ✅ Service Point Photos API

## Технологический стек

- Ruby 3.3.7
- Rails 8.0.2 (API Mode)
- PostgreSQL 15
- Redis 7
- JWT для аутентификации
- Active Model Serializers
- Pundit для авторизации
- Pagy для пагинации
- Sidekiq для фоновых задач
- AASM для управления статусами
- Active Storage для управления файлами
- RSwag для документации API
- RSpec, Factory Bot и Shoulda Matchers для тестирования
- Sentry для отслеживания ошибок

## Установка и запуск

### Через Docker (рекомендуется)

1. Клонировать репозиторий
```
git clone <repository-url>
cd api
```

2. Запустить через Docker Compose
```
docker-compose up -d
```

Приложение будет доступно по адресу http://localhost:3000

### Локальная установка

1. Клонировать репозиторий
```
git clone <repository-url>
cd api
```

2. Установить зависимости
```
bundle install
```

3. Настроить базу данных
```
rails db:create
rails db:migrate
rails db:seed
```

4. Запустить сервер
```
rails server
```

5. (Опционально) Запустить Sidekiq для обработки фоновых задач
```
bundle exec sidekiq
```

## Документация API

### Swagger UI

Документация API доступна через Swagger UI:

1. Сгенерировать документацию:
```bash
docker-compose exec api bundle exec rake rswag:specs:swaggerize
```
или
```bash
bundle exec rake rswag:specs:swaggerize
```

2. Документация будет доступна по адресу: http://localhost:3000/api-docs

### Аутентификация

Аутентификация осуществляется с помощью JWT токенов. Для получения токена необходимо отправить POST-запрос:

```
POST /api/v1/authenticate
```

Параметры запроса:
```json
{
  "email": "user@example.com",
  "password": "password"
}
```

Ответ:
```json
{
  "auth_token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "role": "client",
    "first_name": "John",
    "last_name": "Doe"
  }
}
```

Для последующих запросов необходимо передавать токен в заголовке `Authorization`:
```
Authorization: eyJhbGciOiJIUzI1NiJ9...
```

### Основные API-ендпоинты

#### Пользователи
```
GET /api/v1/users - получение списка пользователей (только для администраторов)
GET /api/v1/users/:id - получение информации о пользователе
POST /api/v1/users - создание пользователя (только для администраторов)
PUT/PATCH /api/v1/users/:id - обновление информации о пользователе
DELETE /api/v1/users/:id - деактивация пользователя (только для администраторов)
```

#### Клиенты
```
GET /api/v1/clients - получение списка клиентов
GET /api/v1/clients/:id - получение информации о клиенте
POST /api/v1/clients/register - регистрация нового клиента
POST /api/v1/clients/social_auth - аутентификация через социальные сети
PUT/PATCH /api/v1/clients/:id - обновление информации о клиенте
DELETE /api/v1/clients/:id - деактивация клиента
```

#### Сервисные точки
```
GET /api/v1/service_points - получение списка сервисных точек
GET /api/v1/service_points/:id - получение информации о сервисной точке
POST /api/v1/partners/:partner_id/service_points - создание сервисной точки
PUT/PATCH /api/v1/partners/:partner_id/service_points/:id - обновление информации о сервисной точке
DELETE /api/v1/partners/:partner_id/service_points/:id - удаление сервисной точки
GET /api/v1/service_points/nearby?latitude=XX&longitude=XX&distance=YY - поиск ближайших точек
```

#### Бронирования
```
GET /api/v1/clients/:client_id/bookings - получение списка бронирований клиента
GET /api/v1/service_points/:service_point_id/bookings - получение списка бронирований сервисной точки
GET /api/v1/clients/:client_id/bookings/:id - получение информации о бронировании
POST /api/v1/clients/:client_id/bookings - создание бронирования
PUT/PATCH /api/v1/clients/:client_id/bookings/:id - обновление информации о бронировании
DELETE /api/v1/clients/:client_id/bookings/:id - отмена бронирования
POST /api/v1/bookings/:id/confirm - подтверждение бронирования
POST /api/v1/bookings/:id/cancel - отмена бронирования
POST /api/v1/bookings/:id/complete - завершение бронирования
POST /api/v1/bookings/:id/no_show - отметка о неявке клиента
```

#### Расписание
```
GET /api/v1/schedule/:service_point_id/:date - получение расписания на день
GET /api/v1/schedule/:service_point_id/:from_date/:to_date - получение расписания на период
```

#### Автомобили клиентов
```
GET /api/v1/clients/:client_id/cars - получение списка автомобилей клиента
GET /api/v1/clients/:client_id/cars/:id - получение информации об автомобиле
POST /api/v1/clients/:client_id/cars - добавление автомобиля
PUT/PATCH /api/v1/clients/:client_id/cars/:id - обновление информации об автомобиле
DELETE /api/v1/clients/:client_id/cars/:id - удаление автомобиля
```

#### Отзывы
```
GET /api/v1/service_points/:service_point_id/reviews - получение списка отзывов о сервисной точке
GET /api/v1/clients/:client_id/reviews - получение списка отзывов клиента
GET /api/v1/clients/:client_id/reviews/:id - получение информации об отзыве
POST /api/v1/clients/:client_id/reviews - создание отзыва
PUT/PATCH /api/v1/clients/:client_id/reviews/:id - обновление отзыва
DELETE /api/v1/clients/:client_id/reviews/:id - удаление отзыва
```

#### Справочники
```
GET /api/v1/regions - получение списка регионов
GET /api/v1/cities - получение списка городов
GET /api/v1/car_brands - получение списка марок автомобилей
GET /api/v1/car_models - получение списка моделей автомобилей
GET /api/v1/tire_types - получение списка типов шин
GET /api/v1/service_categories - получение списка категорий услуг
GET /api/v1/services - получение списка услуг
GET /api/v1/booking_statuses - получение списка статусов бронирований
GET /api/v1/payment_statuses - получение списка статусов оплаты
GET /api/v1/cancellation_reasons - получение списка причин отмены
GET /api/v1/amenities - получение списка дополнительных услуг
```

## Роли пользователей

Система поддерживает следующие роли пользователей:

1. **Администратор (administrator)** - полный доступ ко всему функционалу
2. **Партнер (partner)** - управление своими сервисными точками, менеджерами и расписанием
3. **Менеджер (manager)** - управление бронированиями в сервисных точках партнера
4. **Клиент (client)** - создание бронирований, управление своими автомобилями и отзывами

## Система бронирования

Бронирование проходит через следующие статусы:
1. pending (в ожидании)
2. confirmed (подтверждено)
3. in_progress (в процессе)
4. completed (завершено)
5. canceled_by_client (отменено клиентом)
6. canceled_by_partner (отменено партнером)
7. no_show (клиент не пришел)

## Система уведомлений

Система поддерживает уведомления пользователей о:
- Новых бронированиях
- Изменении статуса бронирования
- Скорых записях
- Промо-акциях
- Системных сообщениях
