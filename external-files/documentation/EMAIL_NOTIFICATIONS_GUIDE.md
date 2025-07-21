# 📧 Гайд по системе автоматических Email уведомлений

## 📋 Обзор системы

Система Tire Service автоматически отправляет email уведомления клиентам по различным событиям. В системе есть **8 типов шаблонов** и **автоматические события**.

---

## 🎯 Типы автоматических уведомлений

### 1️⃣ **Бронирование (Booking Events)**

#### ✅ При создании бронирования (`after_create`)
- **Шаблон**: `booking_confirmation`
- **Получатель**: Клиент
- **Когда**: Сразу после создания записи
- **Переменные**: `{client_name}`, `{booking_date}`, `{booking_time}`, `{service_point_name}`, `{service_name}`, `{booking_id}`

#### ✅ При подтверждении (`status: confirmed`)
- **Шаблон**: `booking_confirmation` 
- **Получатель**: Клиент
- **Когда**: Админ/партнер подтверждает запись
- **Дополнительно**: Push + SMS уведомления

#### ❌ При отмене (`status: cancelled_by_client/cancelled_by_partner`)
- **Шаблон**: `booking_cancelled`
- **Получатель**: Клиент или Партнер (в зависимости от того, кто отменил)
- **Когда**: Изменение статуса на "отменено"

#### ✅ При завершении (`status: completed`)
- **Шаблон**: `service_completed` + `review_request`
- **Получатель**: Клиент
- **Когда**: Работы завершены
- **Цель**: Благодарность + просьба оставить отзыв

### 2️⃣ **Напоминания (Reminders)**

#### 📅 За день до записи
- **Шаблон**: `booking_reminder`
- **Получатель**: Клиент
- **Когда**: Запускается через Cron Job
- **Каналы**: Email + Push

#### ⏰ За 2 часа до записи
- **Шаблон**: `booking_reminder`
- **Получатель**: Клиент  
- **Когда**: Запускается через Cron Job
- **Каналы**: SMS + Push (без email)

### 3️⃣ **Системные события**

#### 👋 Регистрация пользователя
- **Шаблон**: `user_welcome`
- **Получатель**: Новый пользователь
- **Когда**: После успешной регистрации
- **Цель**: Приветствие + инструкции

#### 🔑 Сброс пароля
- **Шаблон**: `password_reset`
- **Получатель**: Пользователь
- **Когда**: Запрос восстановления пароля
- **Переменные**: `{reset_token}`, `{reset_url}`

#### 📰 Информационные рассылки
- **Шаблон**: `newsletter`
- **Получатель**: Выбранные клиенты
- **Когда**: Ручная отправка через админку
- **Цель**: Акции, новости, полезная информация

---

## 🔧 Техническая реализация

### Архитектура системы

```
Событие → BookingNotificationJob → NotificationService → EmailTemplate → TestMailer → SMTP
```

### Основные компоненты:

1. **Модель Booking** - колбэки `after_create`, `after_update`
2. **BookingNotificationJob** - фоновая обработка уведомлений
3. **NotificationService** - центральный сервис уведомлений
4. **EmailTemplate** - шаблоны в базе данных
5. **TestMailer** - отправка email с заменой переменных

---

## ⚠️ Текущее состояние интеграции

### ✅ Что работает:
- События в модели Booking настроены
- Background Jobs созданы
- EmailTemplate система готова
- TestMailer интегрирован с шаблонами

### ❌ Что нужно исправить:
- **NotificationService** не использует EmailTemplate
- **BookingMailer** использует старые статические шаблоны
- **NotificationMailer** не интегрирован с новыми шаблонами

---

## 🚀 Как протестировать автоматические уведомления

### 1. Создание бронирования
```bash
# Через API
curl -X POST http://localhost:8000/api/v1/client_bookings \
  -H "Content-Type: application/json" \
  -d '{"booking_date": "2025-07-25", "start_time": "14:00", "client_id": 1, "service_point_id": 1}'
```

### 2. Изменение статуса
```bash
# Подтверждение
curl -X PATCH http://localhost:8000/api/v1/bookings/ID \
  -H "Content-Type: application/json" \
  -d '{"status": "confirmed"}'
```

### 3. Тестирование шаблонов
```bash
# Через API
curl -X POST http://localhost:8000/api/v1/email_test/send_template \
  -H "Content-Type: application/json" \
  -d '{"template_id": 10, "recipient_email": "test@example.com"}'

# Через Rails console
rails runner test_email_sending.rb your@email.com
```

---

## 📊 Мониторинг уведомлений

### Логи системы:
```bash
# Просмотр логов отправки
tail -f log/development.log | grep -i "email\|notification\|mailer"

# Проверка очереди Jobs
rails runner 'puts "Active Jobs: #{Sidekiq::Queue.new.size}"'
```

### Проверка шаблонов в БД:
```ruby
# Rails console
EmailTemplate.where(is_active: true).pluck(:name, :template_type)
CustomVariable.where(is_active: true).pluck(:name, :example_value)
```

---

## 🎯 Следующие шаги для полной интеграции

1. **Обновить NotificationService** - использовать EmailTemplate вместо статических шаблонов
2. **Создать EmailTemplateMailer** - универсальный mailer для всех шаблонов  
3. **Настроить Cron Jobs** - для автоматических напоминаний
4. **Добавить массовые рассылки** - через админку
5. **Интегрировать с Telegram/Push** - для мультиканальных уведомлений

---

## 📞 Поддержка

При проблемах с отправкой email:
1. Проверьте SMTP настройки в `.env`
2. Убедитесь, что шаблон активен (`is_active: true`)
3. Проверьте логи Rails на ошибки
4. Используйте тестовые API endpoints для отладки 