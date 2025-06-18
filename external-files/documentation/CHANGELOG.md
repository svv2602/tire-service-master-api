# Журнал изменений (CHANGELOG)

Все значимые изменения в этом проекте будут документированы в этом файле.

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.0.0/),
и этот проект придерживается [семантического версионирования](https://semver.org/lang/ru/).

## [1.4.0] - 2025-01-16

### Добавлено
- 🆕 **Service Posts API** - полное управление постами обслуживания
  - GET /api/v1/service_points/{id}/service_posts - список постов
  - POST /api/v1/service_points/{id}/service_posts - создание поста
  - PUT /api/v1/service_points/{id}/service_posts/{post_id} - обновление поста
  - DELETE /api/v1/service_points/{id}/service_posts/{post_id} - удаление поста
  - POST /api/v1/service_points/{id}/service_posts/create_defaults - создание стандартных постов
  - POST /api/v1/service_points/{id}/service_posts/{post_id}/activate - активация поста
  - POST /api/v1/service_points/{id}/service_posts/{post_id}/deactivate - деактивация поста
  - GET /api/v1/service_points/{id}/service_posts/statistics - статистика постов

- 🆕 **Work Statuses API** - статусы работы сервисных точек
  - GET /api/v1/service_points/work_statuses - получение списка статусов

- 🆕 **Обновленный Schedule API** - расписание с поддержкой постов
  - GET /api/v1/service_points/{id}/schedule?date=YYYY-MM-DD - получение расписания

- 🧪 **Файлы поддержки тестирования**
  - spec/support/disable_callbacks.rb - отключение callback'ов в тестах
  - spec/support/faker.rb - управление Faker
  - TESTING.md - руководство по тестированию

### Изменено
- 🔄 **Система статусов ServicePoint** - переход от status_id к is_active + work_status
- 🔄 **ServicePointSerializer** - добавлены новые поля status_display, posts_count, service_posts_summary
- 🔄 **User Factory** - изменен email на sequence для уникальности
- 🔄 **Partner Factory** - обновлена логика создания пользователей
- 🔄 **ServicePoint Factory** - добавлены новые поля is_active и work_status

### Исправлено
- 🐛 **404 ошибка расписания** - добавлен отсутствующий маршрут /api/v1/service_points/{id}/schedule
- 🐛 **500 ошибка ServicePointSerializer** - исправлен метод status для новой системы статусов
- 🐛 **500 ошибка ServicePointServicesController** - исправлен метод current_price_for_service_point
- 🐛 **Проблемы тестов** - решена проблема с callback'ами User, создающими конфликты уникальности
- 🐛 **Faker уникальность** - исправлены проблемы с Faker::UniqueGenerator::RetryLimitExceeded
- 🐛 **Изоляция тестов** - переработаны тесты для полной изоляции друг от друга

### Удалено
- ❌ **Deprecated статусы** - больше не используется связь с таблицей service_point_statuses в API
- ❌ **Временные файлы** - удалены временные тестовые скрипты и диагностические файлы

### Безопасность
- 🔒 **Авторизация постов** - Service Posts API требует авторизации Admin или Partner для модификации
- 🔒 **Статистика постов** - доступ к статистике только для Admin и Manager

### Тестирование
- ✅ **7 новых тестов** для ServicePostsController - все проходят успешно
- ✅ **Исправлены фабрики** - устранены конфликты уникальности
- ✅ **Отключены callback'и** - предотвращены конфликты в тестовой среде

---

## [1.3.0] - 2024-12-XX

### Добавлено
- Управление сервисными точками (CRUD)
- Интеграция с партнерами
- Система фотографий сервисных точек
- Поиск ближайших точек
- Swagger документация

### Изменено
- Улучшена структура API ответов
- Добавлена пагинация

---

## [1.2.0] - 2024-11-XX

### Добавлено
- Полноценная система бронирований
- Управление статусами бронирований
- Интеграция с клиентами и услугами
- Email уведомления
- AASM для управления состояниями

---

## [1.1.0] - 2024-10-XX

### Добавлено
- Аутентификация и авторизация
- Управление пользователями
- Регистрация клиентов
- Базовый API
- Pundit для авторизации

---

## [1.0.0] - 2024-09-XX

### Добавлено
- Первоначальная архитектура API
- Базовые модели данных
- JWT аутентификация
- Swagger документация
- PostgreSQL база данных
- Redis для кеширования

---

## Легенда символов

- 🆕 Новая функция
- 🔄 Изменение существующей функции
- 🐛 Исправление ошибки
- ❌ Удаление
- 🔒 Безопасность
- 🧪 Тестирование
- ✅ Улучшение
- ⚠️ Устаревшее (deprecated)

---

**Примечание**: Версии до 1.4.0 могут содержать неполную информацию, так как журнал изменений ведется с версии 1.4.0. 