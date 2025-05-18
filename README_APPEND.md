## Тестирование

Для тестирования API настроен RSpec с интеграцией Factory Bot и Database Cleaner:

```bash
# Запуск всех тестов
docker-compose exec api bundle exec rspec

# Запуск тестов для моделей
docker-compose exec api bundle exec rspec spec/models

# Запуск тестов для контроллеров
docker-compose exec api bundle exec rspec spec/requests
```

## Мониторинг и логирование

Настроено структурированное логирование в формате JSON с поддержкой Sentry для отслеживания ошибок:

- Логи доступны в контейнере: `docker-compose logs -f api`
- В production окружении ошибки автоматически отправляются в Sentry
- Настроено отслеживание медленных запросов к базе данных (свыше 500ms)
- Все HTTP запросы логируются с информацией о времени выполнения

### Конфигурация мониторинга

Для использования Sentry необходимо добавить переменную окружения:

```
SENTRY_DSN=https://your-sentry-dsn
```

## Миграция данных

Для экспорта/импорта данных между окружениями:

```bash
# Экспорт данных в CSV
docker-compose exec api bundle exec rake db:export_csv

# Импорт данных из CSV
docker-compose exec api bundle exec rake db:import_csv
```

Файлы CSV будут сохранены в директории `db/csv_data/`.

## Обновленная архитектура API

API переработано для более последовательного нейминга и структуры:

- **Аутентификация**:
  - POST /api/v1/authenticate - вход в систему
  - POST /api/v1/register - регистрация нового пользователя

- **Сервисные точки**:
  - GET /api/v1/service_points - список сервисных центров
  - GET /api/v1/service_points/:id - детали сервисного центра
  - GET /api/v1/service_points/nearby - ближайшие центры по координатам

- **Бронирования**:
  - GET /api/v1/bookings - список бронирований пользователя
  - POST /api/v1/bookings - создание нового бронирования
  - GET /api/v1/bookings/:id - детали бронирования
  - PUT/PATCH /api/v1/bookings/:id - обновление бронирования
  - DELETE /api/v1/bookings/:id - отмена бронирования

Подробная документация доступна через Swagger UI.

## Участие в разработке

1. Fork репозитория
2. Создать ветку для новой функциональности (`git checkout -b feature/amazing-feature`)
3. Зафиксировать изменения (`git commit -m 'Add some amazing feature'`)
4. Push ветки в свой fork (`git push origin feature/amazing-feature`)
5. Открыть Pull Request
