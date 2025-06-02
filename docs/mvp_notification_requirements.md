# Требования к системе уведомлений для MVP

## 🎯 Основные сценарии уведомлений

### 1. Уведомления клиентам
- 📧 **Создание бронирования** - подтверждение записи
- 📧 **Подтверждение бронирования** - партнер подтвердил
- 📧 **Напоминание** - за 1 день и за 2 часа до записи
- 📧 **Отмена бронирования** - уведомление об отмене
- 📧 **Завершение обслуживания** - просьба оставить отзыв

### 2. Уведомления партнерам/менеджерам
- 📧 **Новое бронирование** - поступила новая запись
- 📧 **Отмена клиентом** - клиент отменил запись
- 📧 **Скорые записи** - напоминание о записях на сегодня
- 📧 **Сводка дня** - отчет по записям

### 3. Системные уведомления
- 📧 **Ошибки системы** - критические сбои
- 📧 **Отчеты** - ежедневные сводки администраторам

## 🛠 Технические требования

### 1. Email Mailers (создать)

```ruby
# BookingMailer - основной mailer для бронирований
class BookingMailer < ApplicationMailer
  def booking_created(booking_id)
  def booking_confirmed(booking_id)
  def booking_reminder(booking_id)
  def booking_cancelled(booking_id)
  def booking_completed(booking_id)
  
  # Для партнеров
  def new_booking_notification(booking_id, partner_id)
  def booking_cancelled_notification(booking_id, partner_id)
end

# NotificationMailer - системные уведомления
class NotificationMailer < ApplicationMailer
  def daily_summary(partner_id, date)
  def system_alert(message, recipient)
  def booking_reminders_batch(bookings_ids)
end
```

### 2. Сервис уведомлений

```ruby
class NotificationService
  # Отправка уведомлений
  def self.send_booking_notification(booking, notification_type)
  
  # Пакетная отправка
  def self.send_daily_reminders
  def self.send_booking_reminders
  
  # Создание записи уведомления
  def self.create_notification(recipient, type, data)
  
  # Обработка шаблонов
  def self.render_template(template, variables)
end
```

### 3. Background Jobs

```ruby
# BookingNotificationJob - асинхронная отправка
class BookingNotificationJob < ApplicationJob
  def perform(booking_id, notification_type)
    # Отправка уведомления о бронировании
  end
end

# DailyRemindersJob - ежедневные напоминания
class DailyRemindersJob < ApplicationJob
  def perform(date = Date.current)
    # Отправка напоминаний на завтра
  end
end

# BookingRemindersJob - напоминания за 2 часа
class BookingRemindersJob < ApplicationJob
  def perform
    # Отправка напоминаний на сегодня
  end
end
```

### 4. Email шаблоны (создать views)

```
app/views/booking_mailer/
  - booking_created.html.erb / .text.erb
  - booking_confirmed.html.erb / .text.erb  
  - booking_reminder.html.erb / .text.erb
  - booking_cancelled.html.erb / .text.erb
  - booking_completed.html.erb / .text.erb
  - new_booking_notification.html.erb / .text.erb

app/views/layouts/
  - mailer.html.erb (обновить)
  - mailer.text.erb (создать)
```

### 5. Настройка Action Mailer

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: ENV['SMTP_ADDRESS'],
  port: ENV['SMTP_PORT'],
  domain: ENV['SMTP_DOMAIN'],
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}

# config/environments/production.rb  
# Аналогичные настройки для production
```

### 6. Модели - добавить коллбэки

```ruby
# В модели Booking добавить:
after_create :send_creation_notification
after_update :send_status_change_notification, if: :saved_change_to_status_id?

private

def send_creation_notification
  BookingNotificationJob.perform_later(id, 'booking_created')
end

def send_status_change_notification
  case status.name
  when 'confirmed'
    BookingNotificationJob.perform_later(id, 'booking_confirmed')
  when 'canceled_by_client', 'canceled_by_partner'  
    BookingNotificationJob.perform_later(id, 'booking_cancelled')
  when 'completed'
    BookingNotificationJob.perform_later(id, 'booking_completed')
  end
end
```

### 7. Cron Jobs (whenever gem)

```ruby
# config/schedule.rb
every 1.day, at: '8:00 am' do
  runner "DailyRemindersJob.perform_later"
end

every 30.minutes do
  runner "BookingRemindersJob.perform_later"
end

every 1.day, at: '9:00 pm' do  
  runner "NotificationService.send_daily_summaries"
end
```

## 📊 Приоритетность реализации

### Приоритет 1 (критично для MVP):
1. **BookingMailer** с основными уведомлениями
2. **NotificationService** для управления отправкой
3. **Email шаблоны** для клиентов и партнеров
4. **BookingNotificationJob** для асинхронной отправки
5. **Коллбэки в модели Booking**

### Приоритет 2 (важно):
1. **DailyRemindersJob** - напоминания за день
2. **BookingRemindersJob** - напоминания за 2 часа  
3. **Настройка SMTP** для production
4. **Шаблоны для партнеров**

### Приоритет 3 (улучшения):
1. Push уведомления
2. SMS уведомления  
3. Персонализация шаблонов
4. Аналитика открытий писем

## 🧪 Тестирование уведомлений

### Тесты mailers:
```ruby
# spec/mailers/booking_mailer_spec.rb
RSpec.describe BookingMailer do
  describe '#booking_created' do
    it 'sends email to client'
    it 'includes booking details'
    it 'has correct subject'
  end
  
  # Аналогично для других методов
end
```

### Интеграционные тесты:
```ruby  
# spec/jobs/booking_notification_job_spec.rb
RSpec.describe BookingNotificationJob do
  it 'delivers email when booking is created'
  it 'handles missing booking gracefully'
end
```

### Тесты производительности:
1. Время отправки batch уведомлений
2. Обработка очередей при пиковых нагрузках
3. Устойчивость к сбоям SMTP

## 🔧 Настройка окружения

### Переменные среды:
```
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=your-domain.com
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=noreply@your-domain.com
```

### Gemfile добавить:
```ruby
gem 'whenever', require: false # для cron jobs
gem 'sidekiq' # для background jobs (если не используется)
``` 