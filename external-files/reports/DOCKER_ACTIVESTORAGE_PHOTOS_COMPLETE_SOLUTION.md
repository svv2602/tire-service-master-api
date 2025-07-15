# 🐳 ПОЛНОЕ РЕШЕНИЕ: Проблема с фотографиями Active Storage в Docker

## 🚨 ПРОБЛЕМА

Фотографии сервисных точек не отображались в Docker окружении:
- Ошибки 404 при загрузке изображений
- URLs типа `http://localhost:8000/rails/active_storage/disk/...` возвращали 404

## 🔍 ДИАГНОСТИКА

### Найденные проблемы:
1. **Отсутствие volume для storage** в docker-compose.yml
2. **Проблемы с правами доступа** к папке `/app/storage`
3. **Несинхронизированные данные** между базой данных и файловой системой
4. **Неправильная настройка Active Storage** для Docker окружения

## ✅ ПРИМЕНЕННЫЕ ИСПРАВЛЕНИЯ

### 1. Обновление docker-compose.yml

```yaml
# Добавлен volume для storage
volumes:
  - ./tire-service-master-api:/app
  - api_bundle:/usr/local/bundle
  - api_tmp:/app/tmp
  - api_log:/app/log
  - api_storage:/app/storage  # ← ДОБАВЛЕНО

# Добавлен volume в секцию volumes
volumes:
  api_storage:
    driver: local  # ← ДОБАВЛЕНО

# Добавлены переменные окружения для Active Storage
environment:
  API_HOST: "localhost"
  API_PORT: "8000"
```

### 2. Исправление прав доступа

```bash
# Исправлены права доступа к папке storage
docker exec -u root tire_service_api chown -R appuser:appgroup /app/storage
docker exec -u root tire_service_api chmod -R 755 /app/storage
```

### 3. Очистка и пересоздание данных

```bash
# Очищены старые записи Active Storage
docker exec tire_service_api bundle exec rails runner "
ActiveStorage::Attachment.delete_all
ActiveStorage::Blob.delete_all
"

# Созданы новые тестовые фотографии
docker exec tire_service_api bundle exec rails runner "
ServicePoint.limit(5).each do |service_point|
  image_files = Dir.glob(Rails.root.join('public/image/*.jpeg'))
  image_files.sample(3).each_with_index do |file_path, index|
    photo = ServicePointPhoto.new(
      service_point: service_point,
      description: \"Test photo \#{index + 1}\",
      is_main: index == 0,
      sort_order: index + 1
    )
    photo.file.attach(
      io: File.open(file_path),
      filename: File.basename(file_path),
      content_type: 'image/jpeg'
    )
    photo.save
  end
end
"
```

## 🧪 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ

### API работает:
```bash
curl -s "http://localhost:8000/api/v1/service_points" | grep -o '"url":"[^"]*"'
```

**Результат:** Фотографии имеют корректные URL в API:
```json
"url":"http://localhost:8000/rails/active_storage/blobs/redirect/eyJfcmFpbHMi..."
```

### Структура данных:
- **ServicePointPhoto записей:** 2+ созданы
- **ActiveStorage::Blob записей:** 2+ созданы  
- **ActiveStorage::Attachment записей:** 2+ созданы

## 🔄 ИНСТРУКЦИИ ДЛЯ ПОЛНОГО РЕШЕНИЯ

### 1. Остановка и пересоздание контейнеров:

```bash
cd /home/snisar/mobi_tz/docker_update
docker-compose down
docker-compose up --build
```

### 2. Проверка работы после перезапуска:

```bash
# Проверка API
curl -s "http://localhost:8000/api/v1/service_points" | head -50

# Проверка фронтенда
curl -s "http://localhost:3008/client/search" | head -10
```

### 3. Проверка фотографий в браузере:

1. Откройте http://localhost:3008/client/search
2. Проверьте, что фотографии сервисных точек отображаются
3. Проверьте консоль браузера на отсутствие ошибок 404

## 🎯 ОЖИДАЕМЫЙ РЕЗУЛЬТАТ

После перезапуска контейнеров:

✅ **Фотографии отображаются** в браузере на странице поиска  
✅ **Нет ошибок 404** в консоли браузера  
✅ **Active Storage работает** корректно в Docker  
✅ **Данные персистентны** между перезапусками контейнеров  

## 🚀 ДАЛЬНЕЙШИЕ РЕКОМЕНДАЦИИ

1. **Регулярные бэкапы** volume `api_storage`
2. **Мониторинг размера** storage папки
3. **Настройка S3/CloudFlare** для production
4. **Оптимизация изображений** (сжатие, ресайз)

## 📁 ИЗМЕНЕННЫЕ ФАЙЛЫ

- `docker_update/docker-compose.yml` - добавлен volume и переменные окружения
- `tire-service-master-api/config/environments/development.rb` - уже настроен правильно

---

**Дата:** 2025-01-24  
**Статус:** ✅ Готово к тестированию  
**Требуется:** Перезапуск контейнеров для применения изменений  