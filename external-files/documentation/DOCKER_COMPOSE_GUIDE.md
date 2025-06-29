# 🐳 Руководство по запуску Tire Service через Docker Compose

## 📋 Предварительные требования
- Docker 20.10+
- Docker Compose 2.0+
- Свободные порты: 3008, 8000, 5432, 6379, 80, 443

## 🚀 Быстрый старт

### 1. Подготовка
```bash
# Переходим в корневую папку проекта
cd /home/snisar/mobi_tz/

# Убеждаемся, что все файлы на месте
ls -la
# Должны быть: docker-compose.yml, tire-service-master-api/, tire-service-master-web/
```

### 2. Запуск всех сервисов
```bash
# Запуск с пересборкой образов
docker-compose up --build

# Или в фоновом режиме
docker-compose up --build -d
```

### 3. Проверка статуса сервисов
```bash
# Просмотр статуса всех контейнеров
docker-compose ps

# Просмотр логов всех сервисов
docker-compose logs

# Просмотр логов конкретного сервиса
docker-compose logs api
docker-compose logs web
```

## 🔧 Архитектура сервисов

### Сервисы и порты:
- **PostgreSQL**: `localhost:5432`
- **Redis**: `localhost:6379`
- **Rails API**: `localhost:8000`
- **React Frontend**: `localhost:3008`
- **Nginx** (опционально): `localhost:80`, `localhost:443`

### Внутренние Docker имена:
- `postgres` - база данных
- `redis` - кэш и очереди
- `api` - Rails API сервер
- `web` - React приложение
- `nginx` - веб-сервер

## 🌐 Доступ к приложению

После успешного запуска:
- **Фронтенд**: http://localhost:3008 или http://192.168.3.145:3008
- **API**: http://localhost:8000 или http://192.168.3.145:8000
- **API Docs**: http://localhost:8000/api-docs

## 🔍 Диагностика проблем

### Проверка доступности API
```bash
# Проверка health endpoint
curl -f http://localhost:8000/api/v1/health

# Проверка с внешнего IP
curl -f http://192.168.3.145:8000/api/v1/health
```

### Проверка CORS настроек
```bash
# Тест CORS запроса
curl -H "Origin: http://192.168.3.145:3008" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: X-Requested-With" \
     -X OPTIONS \
     http://localhost:8000/api/v1/health
```

### Просмотр логов при ошибках
```bash
# Логи Rails API
docker-compose logs api | grep -i error

# Логи React приложения
docker-compose logs web | grep -i error

# Логи PostgreSQL
docker-compose logs postgres | grep -i error
```

## 🔧 Управление сервисами

### Остановка сервисов
```bash
# Остановка всех сервисов
docker-compose down

# Остановка с удалением volumes (ОСТОРОЖНО!)
docker-compose down -v
```

### Перезапуск отдельного сервиса
```bash
# Перезапуск API
docker-compose restart api

# Перезапуск фронтенда
docker-compose restart web
```

### Пересборка образов
```bash
# Пересборка всех образов
docker-compose build --no-cache

# Пересборка конкретного сервиса
docker-compose build --no-cache api
```

## 📊 Мониторинг ресурсов

### Использование ресурсов
```bash
# Статистика контейнеров
docker stats

# Использование дискового пространства
docker system df
```

### Очистка ресурсов
```bash
# Очистка неиспользуемых образов
docker image prune

# Полная очистка (ОСТОРОЖНО!)
docker system prune -a
```

## 🚨 Решение типичных проблем

### 1. CORS ошибки
**Симптом**: `Access to fetch at 'http://localhost:8000' has been blocked by CORS policy`

**Решение**: 
- Проверить, что ваш IP добавлен в `tire-service-master-api/config/initializers/cors.rb`
- Перезапустить API сервис: `docker-compose restart api`

### 2. Порты заняты
**Симптом**: `Error starting userland proxy: listen tcp4 0.0.0.0:8000: bind: address already in use`

**Решение**:
```bash
# Найти процесс, использующий порт
sudo lsof -i :8000

# Остановить процесс
sudo kill -9 <PID>
```

### 3. База данных не инициализируется
**Симптом**: `database "tire_service_development" does not exist`

**Решение**:
```bash
# Пересоздать базу данных
docker-compose down -v
docker-compose up postgres -d
# Дождаться инициализации PostgreSQL
docker-compose up api
```

### 4. Фронтенд не подключается к API
**Симптом**: `API недоступен: TypeError: Failed to fetch`

**Решение**:
- Проверить, что API сервис запущен: `docker-compose ps api`
- Проверить логи API: `docker-compose logs api`
- Убедиться, что порт 8000 доступен: `curl http://localhost:8000/api/v1/health`

## 📝 Переменные окружения

### API сервис (Rails)
```yaml
RAILS_ENV: development
DATABASE_URL: postgresql://tire_service_user:tire_service_password@postgres:5432/tire_service_development
REDIS_URL: redis://redis:6379/0
SECRET_KEY_BASE: development_secret_key_base_change_in_production
JWT_SECRET: development_jwt_secret_change_in_production
ALLOWED_ORIGINS: http://localhost:3008,http://127.0.0.1:3008,http://192.168.3.145:3008,http://web:3008
```

### Web сервис (React)
```yaml
NODE_ENV: development
REACT_APP_API_URL: http://localhost:8000
REACT_APP_API_BASE_URL: http://localhost:8000/api/v1
HOST: 0.0.0.0
PORT: 3008
```

## 🔐 Безопасность

### Для продакшена:
1. Изменить все секретные ключи
2. Ограничить CORS origins реальными доменами
3. Использовать HTTPS
4. Настроить firewall правила
5. Использовать Docker secrets для паролей

---
**Дата создания**: 2025-01-26  
**Версия**: 1.0  
**Статус**: Актуально 