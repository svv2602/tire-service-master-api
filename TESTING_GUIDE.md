# Руководство по тестированию ServicePoints API

## Обзор новых тестов

Добавлены комплексные тесты для покрытия новой функциональности управления сервисными точками, включая:

- ✅ **Nested Attributes** - создание и обновление связанных сущностей
- ✅ **FormData Upload** - загрузка файлов через многочастевые формы 
- ✅ **Валидация** - проверка бизнес-логики и ограничений
- ✅ **Unit тесты моделей** - тестирование валидации на уровне модели

## Структура тестов

### 1. Тесты Nested Attributes (`service_points_nested_attributes_spec.rb`)

**Назначение:** Тестирование создания и обновления сервисных точек со связанными данными через JSON API.

**Покрываемая функциональность:**
- Обновление постов обслуживания (`service_posts_attributes`)
- Управление услугами (`services_attributes`) 
- Обновление расписания работы (`working_hours`)
- Удаление через флаг `_destroy`
- Создание новых записей с полными nested attributes

**Ключевые тесты:**
```ruby
# Обновление постов
PATCH /api/v1/partners/:partner_id/service_points/:id
{
  "service_point": {
    "service_posts_attributes": [
      { "id": 1, "name": "Обновленный пост", "_destroy": false },
      { "name": "Новый пост", "post_number": 2 }
    ]
  }
}

# Удаление через _destroy
{
  "service_point": {
    "service_posts_attributes": [
      { "id": 1, "_destroy": true }
    ]
  }
}
```

### 2. Тесты FormData (`service_points_formdata_spec.rb`)

**Назначение:** Тестирование загрузки файлов и обработки данных через multipart/form-data.

**Покрываемая функциональность:**
- Загрузка фотографий через FormData
- Смешанная обработка: существующие записи + новые файлы
- Обработка nested attributes в формате FormData
- Создание сервисных точек с файлами

**Примеры тестовых данных:**
```ruby
# Загрузка фотографий
form_data = {
  'service_point[photos_attributes][0][file]' => test_file,
  'service_point[photos_attributes][0][description]' => 'Описание',
  'service_point[photos_attributes][0][is_main]' => 'true'
}

# Обновление существующей фотографии + новая
form_data = {
  'service_point[photos_attributes][0][id]' => existing_photo.id,
  'service_point[photos_attributes][0][description]' => 'Новое описание',
  'service_point[photos_attributes][1][file]' => new_file
}
```

### 3. Тесты валидации (`service_points_validation_spec.rb`)

**Назначение:** Проверка бизнес-логики, ограничений и обработки ошибок.

**Покрываемые случаи:**
- Дубликаты `post_number` в рамках одной сервисной точки
- Множественные главные фотографии
- Фотографии без файлов
- Дубликаты услуг
- Невалидные данные (отрицательные цены, некорректное время)
- Проверка авторизации и прав доступа
- Лимиты на количество фотографий

**Примеры валидационных тестов:**
```ruby
# Дубликат post_number
{
  service_posts_attributes: [
    { name: 'Пост 1', post_number: 1 },
    { name: 'Пост 2', post_number: 1 }  # Ошибка: дубликат
  ]
}

# Множественные главные фотографии
form_data = {
  'service_point[photos_attributes][0][is_main]' => 'true',
  'service_point[photos_attributes][1][is_main]' => 'true'  # Ошибка
}
```

### 4. Unit тесты моделей (`service_point_photo_spec.rb`)

**Назначение:** Тестирование логики на уровне модели и ActiveRecord валидаций.

**Покрываемая функциональность:**
- Валидации полей (file, sort_order, is_main)
- Ассоциации с ServicePoint
- Scopes (main, ordered)
- Коллбэки (автоустановка sort_order, is_main)
- Методы экземпляра (photo_url)
- Логика удаления (каскадное удаление файлов)

## Запуск тестов

### Все новые тесты сразу:
```bash
bundle exec rspec spec/requests/api/v1/service_points_nested_attributes_spec.rb
bundle exec rspec spec/requests/api/v1/service_points_formdata_spec.rb  
bundle exec rspec spec/requests/api/v1/service_points_validation_spec.rb
bundle exec rspec spec/models/service_point_photo_spec.rb
```

### Отдельные группы тестов:
```bash
# Nested attributes
bundle exec rspec spec/requests/api/v1/service_points_nested_attributes_spec.rb --example "service_posts_attributes"

# FormData загрузка
bundle exec rspec spec/requests/api/v1/service_points_formdata_spec.rb --example "загрузка фотографий"

# Валидация
bundle exec rspec spec/requests/api/v1/service_points_validation_spec.rb --example "дубликат"

# Unit тесты модели
bundle exec rspec spec/models/service_point_photo_spec.rb --example "валидации"
```

### С подробным выводом:
```bash
bundle exec rspec spec/requests/api/v1/service_points_formdata_spec.rb --format documentation
```

## Подготовка тестовой среды

### Настройка базы данных:
```bash
RAILS_ENV=test bin/rails db:environment:set
RAILS_ENV=test bin/rails db:schema:load
```

### Создание тестовых файлов:
Убедитесь что существует файл `spec/fixtures/files/test_logo.png` для тестов загрузки.

## Интерпретация результатов

### Успешные тесты:
```
✓ обновляет существующие посты и создает новые
✓ загружает фотографии через FormData 
✓ возвращает ошибки валидации для дубликатов
```

### Типичные ошибки:
- **500 Internal Server Error** - проблема в контроллере или модели
- **422 Unprocessable Entity** - ошибки валидации (ожидаемые)
- **401/403** - проблемы авторизации
- **ActiveRecord errors** - проблемы с базой данных

### Отладка:
```bash
# Логи тестов
tail -f log/test.log

# Запуск одного теста для отладки
bundle exec rspec spec/requests/api/v1/service_points_formdata_spec.rb:58 --format documentation
```

## Покрытие функциональности

### ✅ Реализовано и протестировано:
- Базовый CRUD для сервисных точек
- Обновление через JSON и FormData
- Nested attributes для постов и расписания 
- Загрузка фотографий
- Валидация основных полей

### 🚧 В разработке:
- Полная поддержка services_attributes
- Валидация времени работы
- Ограничения на количество фотографий
- Оптимизация запросов для nested attributes

### 📋 Планируется:
- Интеграционные тесты с фронтендом
- Тесты производительности для больших объемов данных
- Тесты безопасности (SQL injection, XSS)

## Контрибуция

При добавлении новых функций:

1. **Создайте тесты первым** (TDD подход)
2. **Покройте happy path и edge cases**
3. **Добавьте валидационные тесты**
4. **Обновите эту документацию**

### Шаблон нового теста:
```ruby
describe 'новая функциональность' do
  context 'успешный случай' do
    it 'выполняет ожидаемое действие' do
      # Arrange
      # Act  
      # Assert
    end
  end
  
  context 'граничные случаи' do
    it 'правильно обрабатывает ошибки' do
      # Test error handling
    end
  end
end
```

## FAQ

**Q: Почему некоторые тесты падают?**  
A: Тесты созданы с учетом планируемой функциональности. Некоторые могут падать до полной реализации API.

**Q: Как запустить только рабочие тесты?**  
A: Используйте тэги или фильтры RSpec для исключения проблемных тестов во время разработки.

**Q: Нужно ли обновлять тесты при изменении API?**  
A: Да, тесты должны отражать текущее поведение API. Используйте их как документацию к функциональности. 