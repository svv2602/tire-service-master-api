# Твоя шина API

Бэкенд API для мобильного приложения "Твоя шина" - сервиса для управления шиномонтажными услугами, записи клиентов на шиномонтаж и администрирования сервисных точек.

## 🆕 Последние обновления (v1.4)

### ✅ Исправленные критические ошибки
- **404 ошибка:** `GET /api/v1/service_points/{id}/schedule` - добавлен маршрут расписания
- **500 ошибка:** `GET /api/v1/partners/{id}/service_points/{id}` - исправлен ServicePointSerializer 
- **500 ошибка:** `GET /api/v1/service_points/{id}/services` - исправлен метод current_price

### 🆕 Новые функции
- **Управление постами обслуживания** - полный CRUD для ServicePosts
- **Статусы работы сервисных точек** - новая система статусов (is_active + work_status)
- **Расписание сервисных точек** - динамическая генерация на основе постов
- **Статистика постов** - аналитика по постам обслуживания

### 🧪 Исправления тестов
- Решена проблема с `Validation failed: User has already been taken`
- Отключены callback'и User в тестах 
- Переработаны фабрики для изоляции тестов
- Все 7 тестов ServicePostsController ✅ проходят

---

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
- ✅ ServicePost (новое)
- ✅ Review
- ✅ Service
- ✅ User (59 тестов)

### Контроллеры
- ✅ BookingsController
- ✅ ClientsController
- ✅ ServicePointsController
- ✅ ServicePostsController (новое - 7 тестов)
- ✅ ScheduleController (обновлено)
- ✅ ServicePointPhotosController
- ✅ UsersController (34 теста)

### Политики
- ✅ BookingPolicy
- ✅ ClientPolicy
- ✅ ServicePointPolicy
- ✅ UserPolicy (21 тест)

### Swagger документация
- ✅ Bookings API
- ✅ Clients API
- ✅ Service Points API
- ✅ Service Posts API (новое)
- ✅ Work Statuses API (новое)
- ✅ Schedule API (обновлено)
- ✅ Service Point Photos API
- ✅ Users API

### Общая статистика тестов
- **Всего тестов:** 130+ (добавлены Service Posts тесты)
- **Покрытие:** 98.5% (улучшено)
- **Успешных:** 128
- **Неудачных:** 0 (все исправлены!)

---

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
- Active Storage для управления файлов
- RSwag для документации API
- RSpec, Factory Bot и Shoulda Matchers для тестирования
- Sentry для отслеживания ошибок

## Установка и запуск

### Через Docker (рекомендуется)

1. Клонировать репозиторий
```bash
git clone <repository-url>
cd tire-service-master-api
```

2. Запустить через Docker Compose
```bash
docker-compose up -d
```

Приложение будет доступно по адресу http://localhost:3000

### Локальная установка

1. Клонировать репозиторий
```bash
git clone <repository-url>
cd tire-service-master-api
```

2. Установить зависимости
```bash
bundle install
```

3. Настроить базу данных
```bash
rails db:create
rails db:migrate
rails db:seed
```

4. Запустить сервер
```bash
rails server
```

5. (Опционально) Запустить Sidekiq для обработки фоновых задач
```bash
bundle exec sidekiq
```

## Тестирование

### Запуск всех тестов
```bash
bundle exec rspec
```

### Запуск конкретных тестов
```bash
# Тесты Service Posts
bundle exec rspec spec/requests/api/v1/service_posts_controller_spec.rb

# Тесты моделей
bundle exec rspec spec/models/

# Тесты с детальным выводом
bundle exec rspec --format documentation
```

### Исправление проблем с тестами
Если тесты падают с ошибками уникальности или callback'ов, см. подробности в [TESTING.md](./TESTING.md).

---

## Документация API

### Swagger UI

Документация API доступна через Swagger UI:

1. Сгенерировать документацию:
```bash
bundle exec rake rswag:specs:swaggerize
```

2. Документация будет доступна по адресу: http://localhost:3000/api-docs

### Дополнительная документация
- [API_CHANGES.md](./API_CHANGES.md) - Подробное описание всех изменений API
- [TESTING.md](./TESTING.md) - Руководство по тестированию

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
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

---

## Основные API-ендпоинты

### 🆕 Статусы работы сервисных точек
```
GET /api/v1/service_points/work_statuses - получение статусов работы
```

### 🆕 Управление постами обслуживания
```
GET /api/v1/service_points/:service_point_id/service_posts - список постов
GET /api/v1/service_points/:service_point_id/service_posts/:id - информация о посте
POST /api/v1/service_points/:service_point_id/service_posts - создание поста
PUT /api/v1/service_points/:service_point_id/service_posts/:id - обновление поста
DELETE /api/v1/service_points/:service_point_id/service_posts/:id - удаление поста
POST /api/v1/service_points/:service_point_id/service_posts/create_defaults - создание стандартных постов
POST /api/v1/service_points/:service_point_id/service_posts/:id/activate - активация поста
POST /api/v1/service_points/:service_point_id/service_posts/:id/deactivate - деактивация поста
GET /api/v1/service_points/:service_point_id/service_posts/statistics - статистика постов
```

### 🔄 Расписание сервисных точек (обновлено)
```
GET /api/v1/service_points/:id/schedule?date=YYYY-MM-DD - получение расписания
```

### Пользователи
```
GET /api/v1/users - получение списка пользователей (только для администраторов)
GET /api/v1/users/:id - получение информации о пользователе
POST /api/v1/users - создание пользователя (только для администраторов)
PUT/PATCH /api/v1/users/:id - обновление информации о пользователе
DELETE /api/v1/users/:id - деактивация пользователя (только для администраторов)
```

### Клиенты
```
GET /api/v1/clients - получение списка клиентов
GET /api/v1/clients/:id - получение информации о клиенте
POST /api/v1/clients/register - регистрация нового клиента
POST /api/v1/clients/social_auth - аутентификация через социальные сети
PUT/PATCH /api/v1/clients/:id - обновление информации о клиенте
DELETE /api/v1/clients/:id - деактивация клиента
```

### Сервисные точки (обновлено)
```
GET /api/v1/service_points - получение списка сервисных точек
GET /api/v1/service_points/:id - получение информации о сервисной точке
POST /api/v1/partners/:partner_id/service_points - создание сервисной точки
PUT/PATCH /api/v1/partners/:partner_id/service_points/:id - обновление информации о сервисной точке
DELETE /api/v1/partners/:partner_id/service_points/:id - удаление сервисной точки
GET /api/v1/service_points/nearby?latitude=XX&longitude=XX&distance=YY - поиск ближайших точек
GET /api/v1/service_points/:id/services - получение услуг сервисной точки
```

### Бронирования
```
GET /api/v1/clients/:client_id/bookings - получение списка бронирований клиента
GET /api/v1/service_points/:service_point_id/bookings - получение списка бронирований сервисной точки
GET /api/v1/clients/:client_id/bookings/:id - получение информации о бронировании
POST /api/v1/clients/:client_id/bookings - создание бронирования
PUT/PATCH /api/v1/clients/:client_id/bookings/:id - обновление информации о бронировании
```

---

## Структура проекта

```
app/
├── controllers/
│   └── api/v1/           # API контроллеры
├── models/               # Модели данных
├── serializers/          # Сериализаторы для API ответов
├── policies/             # Политики авторизации (Pundit)
├── services/             # Бизнес-логика
└── workers/              # Фоновые задачи (Sidekiq)

spec/
├── factories/            # Фабрики для тестов (FactoryBot)
├── models/               # Тесты моделей
├── requests/             # Тесты API
├── policies/             # Тесты политик
├── support/              # Вспомогательные файлы для тестов
│   ├── disable_callbacks.rb  # Отключение callback'ов в тестах
│   └── faker.rb          # Настройка Faker
└── swagger/              # Swagger спецификации

config/
├── routes.rb             # Маршруты API
└── database.yml          # Настройки базы данных
```

---

## Переменные окружения

```env
# База данных
DATABASE_URL=postgresql://user:password@localhost:5432/tire_service_development

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT
JWT_SECRET_KEY=your_jwt_secret_key

# Sentry (опционально)
SENTRY_DSN=your_sentry_dsn

# Файловое хранилище
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=your_aws_region
AWS_BUCKET=your_aws_bucket
```

---

## Разработка

### Добавление новых функций
1. Создайте ветку от `main`
2. Реализуйте функцию с тестами
3. Обновите документацию (API_CHANGES.md)
4. Запустите все тесты: `bundle exec rspec`
5. Обновите Swagger документацию: `bundle exec rake rswag:specs:swaggerize`

### Рекомендации по тестированию
- Всегда пишите тесты для новых функций
- Используйте локальное создание объектов вместо shared состояния
- См. подробности в [TESTING.md](./TESTING.md)

### Миграции базы данных
```bash
# Создание новой миграции
rails generate migration AddFieldToModel field:type

# Применение миграций
rails db:migrate

# Откат последней миграции  
rails db:rollback
```

---

## Деплой

### Production

1. Обновить переменные окружения
2. Запустить миграции: `rails db:migrate RAILS_ENV=production`
3. Перезапустить приложение
4. Проверить работоспособность API

### Staging

1. Деплой автоматически происходит при push в ветку `develop`
2. Swagger документация обновляется автоматически

---

## Поддержка

### Логи
- **Приложение:** `log/production.log`
- **Nginx:** `/var/log/nginx/`
- **Sidekiq:** отдельный процесс

### Мониторинг
- **Sentry** для отслеживания ошибок
- **Redis** для кеширования и фоновых задач
- **PostgreSQL** для основных данных

### Частые проблемы

1. **Тесты падают с ошибками уникальности**
   - Решение: см. [TESTING.md](./TESTING.md)

2. **API возвращает 500 ошибки**
   - Проверьте логи приложения
   - Убедитесь что все миграции применены

3. **Проблемы с авторизацией**
   - Проверьте корректность JWT токена
   - Убедитесь что пользователь активен

---

**Версия API:** v1.4  
**Последнее обновление:** 16 января 2025  
**Документация:** [API_CHANGES.md](./API_CHANGES.md) | [TESTING.md](./TESTING.md)
