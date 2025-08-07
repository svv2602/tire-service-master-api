# 🔐 Исправление JWT секретного ключа для Docker окружения

## Проблема
При работе в Docker окружении возникала ошибка `Auth::TokenInvalidError` при попытке refresh токенов, хотя токены успешно создавались при входе.

### Симптомы:
```
Auth#refresh error: Auth::TokenInvalidError
❌ Не удалось обновить токен
```

### Логи показывали:
- Успешный вход с созданием токенов
- Первые 20 запросов работали нормально
- При попытке refresh - ошибка TokenInvalidError

## Корневая причина

### Несоответствие секретных ключей
- **Локально**: Rails использует `Rails.application.credentials.secret_key_base`
- **В Docker**: Устанавливается переменная окружения `SECRET_KEY_BASE`
- **Проблема**: JWT код использовал только credentials, игнорируя ENV переменную

### Последствия:
- Токены, созданные в Docker, не могли быть расшифрованы тем же кодом
- Refresh токены становились недействительными
- Пользователи вылетали из системы

## Исправления

### 1. app/lib/auth/json_web_token.rb

#### Добавлен универсальный метод получения ключа:
```ruby
# Получение секретного ключа из переменной окружения или credentials
def self.secret_key
  ENV['SECRET_KEY_BASE'] || Rails.application.credentials.secret_key_base
end
```

#### Заменены все вхождения:
```ruby
# ДО:
JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')

# ПОСЛЕ:
JWT.encode(payload, secret_key, 'HS256')
```

#### Добавлена отладочная информация:
```ruby
def self.refresh_access_token(refresh_token)
  Rails.logger.info "🔄 Attempting to refresh token with key: #{secret_key[0..10]}..."
  decoded = decode_refresh_token(refresh_token)
  Rails.logger.info "✅ Successfully decoded refresh token for user: #{decoded[:user_id]}"
  
  new_token = encode_access_token(user_id: decoded[:user_id])
  Rails.logger.info "✅ Generated new access token"
  new_token
end
```

### 2. app/lib/json_web_token.rb

#### Аналогичные исправления для консистентности:
- Добавлен метод `secret_key`
- Заменены все обращения к `Rails.application.credentials.secret_key_base`

## Конфигурация Docker

### docker-compose.yml уже содержит правильную настройку:
```yaml
environment:
  SECRET_KEY_BASE: "development_secret_key_base_change_in_production"
  JWT_SECRET: "development_jwt_secret_change_in_production"
```

### Приоритет ключей:
1. `ENV['SECRET_KEY_BASE']` (Docker, production)
2. `Rails.application.credentials.secret_key_base` (локальная разработка)

## Тестирование

### Для проверки исправления:
1. **Пересобрать Docker контейнеры:**
   ```bash
   docker-compose down
   docker-compose build --no-cache api
   docker-compose up -d
   ```

2. **Проверить логи при входе:**
   ```bash
   docker-compose logs -f api | grep "refresh token"
   ```

3. **Ожидаемые логи:**
   ```
   🔄 Attempting to refresh token with key: development...
   ✅ Successfully decoded refresh token for user: 2
   ✅ Generated new access token
   ```

### Критерии успеха:
- ✅ Вход в систему работает
- ✅ Первые запросы выполняются с access токеном
- ✅ Refresh токен успешно обновляется при истечении
- ✅ Пользователь остается авторизованным длительное время
- ✅ Нет ошибок `Auth::TokenInvalidError` в логах

## Безопасность

### Production рекомендации:
```yaml
environment:
  SECRET_KEY_BASE: "your_very_long_random_secret_key_at_least_32_characters"
  JWT_SECRET: "another_different_secret_key_for_jwt_only"
```

### Генерация безопасных ключей:
```bash
# Генерация SECRET_KEY_BASE
rails secret

# Или через OpenSSL
openssl rand -hex 32
```

## Обратная совместимость

### Локальная разработка:
- Продолжает использовать `Rails.application.credentials.secret_key_base`
- Не требует изменений в рабочем процессе

### Docker окружение:
- Использует переменную окружения `SECRET_KEY_BASE`
- Консистентные токены между перезапусками контейнеров

## Мониторинг

### Полезные команды для отладки:
```bash
# Проверить логи JWT операций
docker-compose logs api | grep -E "(refresh token|TokenInvalidError|Generated new)"

# Проверить переменные окружения в контейнере
docker-compose exec api env | grep SECRET

# Тест refresh токена через curl
curl -X POST http://service-station.tot.biz.ua:8000/api/v1/auth/refresh \
     -H "Content-Type: application/json" \
     -b "_tire_service_session=YOUR_SESSION_COOKIE"
```

## Заключение

Исправление обеспечивает:
- ✅ Единый источник секретного ключа для всех окружений
- ✅ Корректную работу refresh токенов в Docker
- ✅ Обратную совместимость с локальной разработкой  
- ✅ Улучшенную отладочную информацию
- ✅ Безопасность production окружения

После применения исправлений проблема с `Auth::TokenInvalidError` должна быть полностью решена.

---
**Дата создания:** $(date '+%Y-%m-%d %H:%M:%S')  
**Автор:** AI Assistant  
**Статус:** Готово к тестированию