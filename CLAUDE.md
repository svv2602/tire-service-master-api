# CLAUDE.md — Backend (Rails API)

## Общие правила

**Язык общения:** русский
**Язык кода и комментариев:** английский
**Коммиты:** `type: краткое описание на русском`

---

## Архитектура проекта

### Стек технологий
- Ruby 3.3.7, Rails 8.0.2 (API-only mode)
- PostgreSQL, Redis, Sidekiq
- JWT аутентификация + Pundit авторизация
- RSpec для тестов
- OpenAI API для AI-функций

### Структура директорий

```
app/
├── controllers/api/v1/     # ВСЕ эндпоинты под /api/v1/
├── models/                 # ActiveRecord + AASM state machines
├── services/               # Бизнес-логика (Service Objects)
├── serializers/            # ActiveModelSerializers
├── policies/               # Pundit policies
└── jobs/                   # Sidekiq background jobs

spec/
├── requests/               # API integration tests
├── models/                 # Model unit tests
└── services/               # Service tests
```

### Роли пользователей
- `admin` — полный доступ
- `partner` — владелец СТО
- `manager` — менеджер партнёра
- `operator` — оператор СТО
- `client` — клиент (автовладелец)

---

## Ключевые сущности

### Основные модели

| Модель | Описание | State Machine |
|--------|----------|---------------|
| User | Пользователь системы | — |
| Partner | Владелец СТО | — |
| ServicePoint | Сервисная точка (СТО) | — |
| Booking | Бронирование | AASM (pending → confirmed → completed) |
| Order | Заказ из магазина поставщика | AASM |
| TireOrder | Заказ шин через платформу | AASM |
| Supplier | Поставщик шин | — |
| PartnerReward | Вознаграждение партнёру | — |

### Связи вознаграждений

```
Supplier
    └── PartnerSupplierAgreement (договорённость)
            ├── RewardRule (правило расчёта)
            └── PartnerSupplierAgreementException (исключения по брендам)
                    └── PartnerReward (начисленное вознаграждение)
```

---

## Сервисы (Service Objects)

### AI-сервисы
| Сервис | Описание |
|--------|----------|
| `TireSearchService` | Умный поиск шин с OpenAI |
| `TireChatService` | Чат-консультант по шинам |
| `OpenaiService` | Обёртка над OpenAI API |
| `CarSearchLlmService` | Поиск авто через LLM |

### Бизнес-логика
| Сервис | Описание |
|--------|----------|
| `BookingManager` | Управление бронированиями |
| `ScheduleManager` | Расписание СТО |
| `DynamicAvailabilityService` | Расчёт доступных слотов |
| `RewardCalculationService` | Расчёт вознаграждений |
| `NotificationService` | Мультиканальные уведомления |
| `TelegramService` | Telegram бот |
| `PushService` | Web Push уведомления |

### Обработка данных
| Сервис | Описание |
|--------|----------|
| `TireNormalizationService` | Нормализация названий шин |
| `TireDataNormalizer` | Парсинг прайсов |
| `SupplierXmlProcessor` | Обработка XML от поставщиков |
| `OrderProcessorService` | Обработка заказов |

---

## API Endpoints

### Аутентификация
```
POST   /api/v1/auth/login      # Вход
POST   /api/v1/auth/logout     # Выход
GET    /api/v1/auth/me         # Текущий пользователь
POST   /api/v1/auth/refresh    # Обновление токена
```

### Клиентское API
```
GET    /api/v1/service_points/search    # Поиск СТО
POST   /api/v1/client_bookings          # Создание записи
GET    /api/v1/availability/:id/:date   # Доступные слоты
POST   /api/v1/tire_search              # Поиск шин (AI)
POST   /api/v1/tire_chat/message        # Чат-консультант
```

### Партнёрское API
```
GET    /api/v1/partners/:id/service_points
GET    /api/v1/partners/:id/orders
POST   /api/v1/partners/:id/orders/:id/mark_as_delivered
```

### Поставщики
```
GET    /api/v1/suppliers
POST   /api/v1/suppliers/:id/upload_price
GET    /api/v1/suppliers/:id/products
```

### Администрирование
```
GET    /api/v1/users
GET    /api/v1/partner_applications
PATCH  /api/v1/partner_applications/:id/update_status
GET    /api/v1/reviews
GET    /api/v1/audit_logs
```

---

## Паттерны кода

### Создание сервиса
```ruby
# app/services/my_service.rb
class MyService < ApplicationService
  def initialize(param1, param2)
    @param1 = param1
    @param2 = param2
  end

  def call
    # Бизнес-логика
    Result.new(success: true, data: result)
  rescue StandardError => e
    Result.new(success: false, error: e.message)
  end
end

# Использование
result = MyService.call(param1, param2)
```

### Создание policy
```ruby
# app/policies/booking_policy.rb
class BookingPolicy < ApplicationPolicy
  def show?
    admin? || owner? || operator_of_service_point?
  end

  def create?
    true # Любой может создать
  end

  def update?
    admin? || owner?
  end

  private

  def owner?
    record.client_id == user.id
  end
end
```

### Создание serializer
```ruby
# app/serializers/booking_serializer.rb
class BookingSerializer < ActiveModel::Serializer
  attributes :id, :status, :booking_date, :start_time, :end_time

  belongs_to :service_point
  belongs_to :client
  has_many :services
end
```

### State Machine (AASM)
```ruby
# app/models/booking.rb
class Booking < ApplicationRecord
  include AASM

  aasm column: :status do
    state :pending, initial: true
    state :confirmed
    state :in_progress
    state :completed
    state :cancelled

    event :confirm do
      transitions from: :pending, to: :confirmed
    end

    event :start do
      transitions from: :confirmed, to: :in_progress
    end

    event :complete do
      transitions from: :in_progress, to: :completed
      after do
        NotificationService.booking_completed(self)
      end
    end
  end
end
```

---

## Тестирование

### Запуск тестов
```bash
bundle exec rspec                          # Все тесты
bundle exec rspec spec/requests/           # Только API тесты
bundle exec rspec spec/models/booking_spec.rb      # Один файл
bundle exec rspec spec/models/booking_spec.rb:42   # Одна строка
```

### Структура теста
```ruby
# spec/requests/api/v1/bookings_spec.rb
require 'rails_helper'

RSpec.describe 'Bookings API', type: :request do
  let(:client) { create(:client) }
  let(:service_point) { create(:service_point) }
  let(:headers) { auth_headers(client.user) }

  describe 'POST /api/v1/client_bookings' do
    let(:valid_params) do
      {
        service_point_id: service_point.id,
        booking_date: Date.tomorrow,
        start_time: '10:00'
      }
    end

    it 'creates a booking' do
      post '/api/v1/client_bookings', params: valid_params, headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('pending')
    end
  end
end
```

---

## Миграции

### Создание
```bash
rails generate migration AddFieldToTable field:type
rails generate model ModelName field:type
```

### Соглашения
- Всегда добавляй индексы для foreign keys
- Используй `null: false` где возможно
- Добавляй `default` значения

```ruby
class CreatePartnerRewards < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_rewards do |t|
      t.references :partner, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, default: 'pending', null: false

      t.timestamps
    end

    add_index :partner_rewards, :status
  end
end
```

---

## Частые задачи

### Добавление нового API endpoint

1. Добавить маршрут в `config/routes.rb`
2. Создать/обновить контроллер в `app/controllers/api/v1/`
3. Создать policy если нужна авторизация
4. Создать serializer для ответа
5. Написать тест в `spec/requests/`

### Добавление фоновой задачи

```ruby
# app/jobs/send_notification_job.rb
class SendNotificationJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = Notification.find(notification_id)
    NotificationService.send(notification)
  end
end

# Вызов
SendNotificationJob.perform_later(notification.id)
```

### Работа с OpenAI

```ruby
# Через сервис
result = OpenaiService.new.chat(
  messages: [{ role: 'user', content: prompt }],
  model: 'gpt-4'
)

# Через TireSearchService
tires = TireSearchService.new(query: 'шины на камри').search
```

---

## Окружение

### Переменные окружения (.env)
```
DATABASE_URL=postgresql://...
REDIS_URL=redis://localhost:6379
JWT_SECRET_KEY=...
OPENAI_API_KEY=sk-...
TELEGRAM_BOT_TOKEN=...
VAPID_PUBLIC_KEY=...
VAPID_PRIVATE_KEY=...
```

### Команды
```bash
rails server -p 8000          # Запуск сервера
rails console                 # Консоль
rails db:migrate              # Миграции
rails db:seed                 # Сиды
bundle exec sidekiq           # Фоновые задачи
```

---

## Что НЕ делать

- НЕ добавлять бизнес-логику в контроллеры — выноси в сервисы
- НЕ делать N+1 запросы — используй `includes`
- НЕ хардкодить строки — используй константы или I18n
- НЕ коммитить секреты — используй ENV переменные
- НЕ пропускать тесты для критичной логики

---

## Git

```bash
cd /home/snisar/mobi_tz/tire-service-master-api
git add .
git commit -m "feat: добавлен расчёт вознаграждений"
```

**Типы коммитов:**
- `feat:` — новый функционал
- `fix:` — исправление бага
- `refactor:` — рефакторинг без изменения функционала
- `test:` — добавление тестов
- `docs:` — документация

---

*Последнее обновление: декабрь 2025*
