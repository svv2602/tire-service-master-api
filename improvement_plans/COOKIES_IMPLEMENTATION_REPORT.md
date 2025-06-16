# Отчет о реализации HttpOnly куки для безопасной аутентификации

## Выполненные изменения

### 1. Обновление конфигурации CORS

Файл: `config/initializers/cors.rb`

```diff
resource "*",
  headers: :any,
  methods: [:get, :post, :put, :patch, :delete, :options, :head],
- credentials: false
+ credentials: true # Изменено на true для поддержки куки
```

Включение параметра `credentials: true` позволяет передавать куки между разными доменами при CORS-запросах.

### 2. Добавление поддержки куки в Rails API

Файл: `config/application.rb`

```ruby
# Добавляем поддержку куки для API приложения
config.middleware.use ActionDispatch::Cookies
config.middleware.use ActionDispatch::Session::CookieStore, key: '_tire_service_session'
```

По умолчанию Rails API приложения не включают middleware для работы с куки, поэтому мы добавили их вручную.

### 3. Обновление контроллера аутентификации

Файл: `app/controllers/api/v1/auth_controller.rb`

#### 3.1. Метод login

```ruby
# Устанавливаем refresh токен в HttpOnly куки
cookies.encrypted[:refresh_token] = {
  value: refresh_token,
  httponly: true,
  secure: Rails.env.production?,
  same_site: :strict,
  expires: 30.days.from_now
}

# Не отправляем refresh токен в JSON ответе, так как он теперь в куки
render json: { 
  tokens: { 
    access: access_token
  },
  user: user_json
}
```

#### 3.2. Метод refresh

```ruby
# Получаем refresh токен из куки вместо заголовка
refresh_token = cookies.encrypted[:refresh_token]

# При ошибке удаляем куки
cookies.delete(:refresh_token)
```

#### 3.3. Метод logout

```ruby
# Удаляем куки при выходе
cookies.delete(:refresh_token)
```

### 4. Обновление контроллера клиентской аутентификации

Файл: `app/controllers/api/v1/client_auth_controller.rb`

Аналогичные изменения были внесены в методы `register`, `login` и `logout`:

- Добавлено создание и установка HttpOnly куки для refresh токена
- Удалена передача refresh токена в JSON ответе
- Добавлено удаление куки при выходе из системы

## Преимущества внесенных изменений

1. **Повышенная безопасность**: Refresh токен теперь хранится в HttpOnly куки, что делает его недоступным для JavaScript и защищает от XSS-атак
2. **Автоматическая отправка**: Куки автоматически отправляются с каждым запросом к домену, что упрощает работу с токенами
3. **Контроль на сервере**: Сервер может управлять жизненным циклом токенов, включая их удаление при выходе
4. **Защита от CSRF**: Использование флага SameSite=Strict защищает от CSRF-атак

## Дальнейшие шаги

1. **Обновление фронтенда**: Необходимо обновить фронтенд для работы с новой системой аутентификации
2. **Тестирование**: Провести тестирование для проверки корректности работы аутентификации
3. **Миграция существующих пользователей**: Реализовать плавный переход для существующих пользователей

## Статус

- [x] Настройка CORS для работы с куки
- [x] Добавление поддержки куки в Rails API
- [x] Обновление контроллера аутентификации
- [x] Обновление контроллера клиентской аутентификации
- [ ] Обновление фронтенда
- [ ] Тестирование
- [ ] Миграция существующих пользователей 