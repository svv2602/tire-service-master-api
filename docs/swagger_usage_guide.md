# Руководство по использованию Swagger документации

## Быстрый старт

### 1. Доступ к документации

#### Локальная разработка:
```bash
# Запуск сервера
rails server

# Открыть в браузере:
http://localhost:8000/api-docs
```

#### Файлы документации:
- **Исходный файл:** `swagger/v1/swagger.yaml`
- **Публичная версия:** `public/api-docs/v1/swagger.yaml`

### 2. Регенерация документации

```bash
# Регенерация из тестов
RAILS_ENV=test bundle exec rake rswag:specs:swaggerize

# Копирование в публичную директорию
cp swagger/v1/swagger.yaml public/api-docs/v1/swagger.yaml
```

## Структура документации

### Разделы API

1. **Authentication** - аутентификация и авторизация
2. **Users** - управление пользователями (админ функции)
3. **Clients** - управление клиентами
4. **Partners** - управление партнерами
5. **Service Points** - управление сервисными точками
6. **Service Posts** - посты обслуживания с индивидуальными расписаниями
7. **Bookings** - управление бронированиями
8. **Cars** - управление автомобилями пользователей
9. **Reviews** - система отзывов и рейтингов
10. **Photos** - управление фотографиями
11. **Catalogs** - справочники (регионы, марки авто, услуги)
12. **Catalogs (Admin)** - административное управление каталогами
13. **Dashboard** - аналитика и статистика
14. **System** - системные endpoints

### Аутентификация

Все защищенные endpoints используют Bearer JWT токены:

```http
Authorization: Bearer <jwt_token>
```

Получение токена:
```bash
POST /api/v1/auth/login
{
  "email": "user@example.com",
  "password": "password"
}
```

## Использование в разработке

### Frontend разработка

1. **Изучите модели данных** в секции `schemas`
2. **Используйте примеры запросов** из документации
3. **Обратите внимание на коды ошибок** (401, 403, 422, 404)
4. **Используйте пагинацию** для списочных endpoints

### Тестирование API

```bash
# Пример запроса получения списка сервисных точек
curl -X GET "http://localhost:8000/api/v1/service_points" \
  -H "Content-Type: application/json"

# Пример аутентифицированного запроса
curl -X GET "http://localhost:8000/api/v1/users/me" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

### Интеграция с внешними системами

1. **Используйте публичные endpoints** без аутентификации для каталогов
2. **Получите API ключи** для доступа к защищенным данным
3. **Следуйте лимитам rate limiting** (если настроены)
4. **Обрабатывайте все типы ошибок** согласно документации

## Полезные команды

### Разработчикам

```bash
# Запуск только Swagger тестов
rspec spec/requests/api/v1/swagger_docs/ --format documentation

# Проверка валидности swagger.yaml
swagger-codegen validate -i swagger/v1/swagger.yaml

# Генерация клиентского SDK (если нужно)
swagger-codegen generate -i swagger/v1/swagger.yaml -l javascript -o client/
```

### QA тестировщикам

```bash
# Запуск всех API тестов
RAILS_ENV=test rspec spec/requests/

# Проверка покрытия тестами
RAILS_ENV=test bundle exec rake rswag:specs:swaggerize
```

## Примеры использования

### Работа с каталогами (публичные endpoints)

```javascript
// Получение списка регионов
fetch('/api/v1/catalogs/regions')
  .then(response => response.json())
  .then(data => console.log(data.data));

// Получение городов по региону
fetch('/api/v1/catalogs/cities?region_id=1')
  .then(response => response.json())
  .then(data => console.log(data.data));
```

### Работа с защищенными данными

```javascript
// Получение информации о текущем пользователе
fetch('/api/v1/users/me', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
})
.then(response => response.json())
.then(data => console.log(data.data));

// Создание автомобиля
fetch('/api/v1/cars', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    car: {
      car_brand_id: 1,
      car_model_id: 1,
      year: 2020,
      license_plate: 'AA1234BB',
      color: 'Черный'
    }
  })
})
.then(response => response.json())
.then(data => console.log(data.data));
```

### Работа с пагинацией

```javascript
// Получение списка с пагинацией
fetch('/api/v1/partners?page=1&per_page=25&query=шина', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
})
.then(response => response.json())
.then(data => {
  console.log('Данные:', data.data);
  console.log('Пагинация:', data.pagination);
});
```

## Обработка ошибок

```javascript
fetch('/api/v1/cars', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    car: { /* некорректные данные */ }
  })
})
.then(response => {
  if (!response.ok) {
    return response.json().then(error => {
      switch (response.status) {
        case 401:
          console.error('Не авторизован:', error);
          // Перенаправление на логин
          break;
        case 403:
          console.error('Недостаточно прав:', error);
          break;
        case 422:
          console.error('Ошибки валидации:', error.errors);
          // Показ ошибок пользователю
          break;
        case 404:
          console.error('Не найдено:', error);
          break;
        default:
          console.error('Ошибка сервера:', error);
      }
      throw error;
    });
  }
  return response.json();
})
.then(data => console.log('Успех:', data))
.catch(error => console.error('Ошибка:', error));
```

---

## Контакты и поддержка

- **Документация обновлена:** $(date)
- **Версия API:** v1
- **Формат:** OpenAPI 3.0
- **Тестовое покрытие:** 489 тестов
- **Статус:** Готова к использованию

Для вопросов по API обращайтесь к команде разработки. 