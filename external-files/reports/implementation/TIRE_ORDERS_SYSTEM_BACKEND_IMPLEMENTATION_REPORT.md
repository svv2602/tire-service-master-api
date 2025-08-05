# 🛒 Отчет: Реализация системы заказов шин - Backend API

## 📋 Обзор
Создана полная backend система для управления заказами шин с корзиной, статусами заказов и API для фронтенда.

## 🗄️ Структура базы данных

### Таблица `tire_orders`
```sql
CREATE TABLE tire_orders (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  supplier_id BIGINT NOT NULL REFERENCES suppliers(id),
  status VARCHAR NOT NULL DEFAULT 'draft',
  client_name VARCHAR NOT NULL,
  client_phone VARCHAR NOT NULL,
  comment TEXT,
  total_amount DECIMAL(10,2) DEFAULT 0.0,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Индексы
CREATE INDEX index_tire_orders_on_user_id_and_status ON tire_orders(user_id, status);
CREATE INDEX index_tire_orders_on_supplier_id_and_status ON tire_orders(supplier_id, status);
CREATE INDEX index_tire_orders_on_status ON tire_orders(status);
```

### Таблица `tire_order_items`
```sql
CREATE TABLE tire_order_items (
  id BIGSERIAL PRIMARY KEY,
  tire_order_id BIGINT NOT NULL REFERENCES tire_orders(id),
  supplier_tire_product_id BIGINT NOT NULL REFERENCES supplier_tire_products(id),
  quantity INTEGER NOT NULL DEFAULT 1,
  price_at_order DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Уникальный индекс - один товар только один раз в заказе
CREATE UNIQUE INDEX index_tire_order_items_unique 
ON tire_order_items(tire_order_id, supplier_tire_product_id);
```

## 🔄 Статусы заказов

### Жизненный цикл заказа
```
draft (корзина) → submitted → confirmed → processing → completed
                     ↓            ↓           ↓
                 cancelled    cancelled   cancelled
                     ↓            ↓           ↓
                 archived     archived    archived
```

### Права на переходы статусов
- **draft → submitted**: Пользователь (отправка заказа)
- **submitted → confirmed**: Только админ
- **confirmed → processing**: Только админ
- **processing → completed**: Только админ
- **любой → cancelled**: Админ всегда, пользователь до completed
- **любой → archived**: Только пользователь (кроме draft)

## 🏗️ Модели Rails

### TireOrder
```ruby
class TireOrder < ApplicationRecord
  STATUSES = {
    'draft' => 'Корзина',
    'submitted' => 'Отправлен',
    'confirmed' => 'Подтвержден',
    'processing' => 'В обработке',
    'completed' => 'Выполнен',
    'cancelled' => 'Отменен',
    'archived' => 'Архивирован'
  }.freeze

  # Связи
  belongs_to :user
  belongs_to :supplier
  has_many :tire_order_items, dependent: :destroy
  has_many :supplier_tire_products, through: :tire_order_items

  # Методы переходов
  def submit!; end
  def confirm!; end
  def start_processing!; end
  def complete!; end
  def cancel!; end
  def archive!; end
end
```

### TireOrderItem
```ruby
class TireOrderItem < ApplicationRecord
  belongs_to :tire_order
  belongs_to :supplier_tire_product

  # Автоматическое заполнение цены при создании
  before_validation :set_price_at_order, on: :create
  
  # Обновление общей суммы заказа
  after_save :update_order_total
  after_destroy :update_order_total
end
```

## 🔌 API Endpoints

### Корзина (`/api/v1/tire_carts`)
```
GET    /api/v1/tire_carts              # Все корзины пользователя
GET    /api/v1/tire_carts/:id          # Конкретная корзина
POST   /api/v1/tire_carts/:id/items    # Добавить товар
PUT    /api/v1/tire_carts/:id/items/:item_id  # Изменить количество
DELETE /api/v1/tire_carts/:id/items/:item_id  # Удалить товар
DELETE /api/v1/tire_carts/:id/clear    # Очистить корзину
DELETE /api/v1/tire_carts/:id          # Удалить корзину
```

### Заказы (`/api/v1/tire_orders`)
```
GET    /api/v1/tire_orders             # Мои заказы
GET    /api/v1/tire_orders/all         # Все заказы (админы)
GET    /api/v1/tire_orders/:id         # Конкретный заказ
POST   /api/v1/tire_orders             # Создать заказы из корзин
PATCH  /api/v1/tire_orders/:id/cancel  # Отменить заказ
PATCH  /api/v1/tire_orders/:id/archive # Архивировать заказ

# Админские действия
PATCH  /api/v1/tire_orders/:id/confirm          # Подтвердить
PATCH  /api/v1/tire_orders/:id/start_processing # Взять в обработку
PATCH  /api/v1/tire_orders/:id/complete         # Завершить
```

## 🔐 Система авторизации

### TireOrderPolicy
```ruby
class TireOrderPolicy < ApplicationPolicy
  def index?; true; end  # Пользователи видят только свои
  def index_all?; user&.admin?; end  # Все заказы только админам
  def show?; user&.admin? || record.user == user; end
  def create?; user.present?; end
  
  def confirm?; user&.admin? && record.submitted?; end
  def start_processing?; user&.admin? && record.status == 'confirmed'; end
  def complete?; user&.admin? && record.status == 'processing'; end
  
  def cancel?
    if user&.admin?
      record.can_be_cancelled_by_admin?
    else
      record.user == user && record.can_be_cancelled_by_user?
    end
  end
  
  def archive?; record.user == user && record.can_be_archived?; end
end
```

## 🛒 Логика корзины и заказов

### Принципы работы
1. **Единая корзина**: Пользователь добавляет товары разных поставщиков в одну корзину
2. **Группировка по поставщикам**: В корзине товары отображаются по поставщикам
3. **Отдельные заказы**: При оформлении создается отдельный заказ для каждого поставщика
4. **Автоматическая очистка**: После создания заказов корзины очищаются

### Процесс оформления заказа
```ruby
# POST /api/v1/tire_orders
def create
  carts = current_user.tire_orders.draft.includes(:tire_order_items)
  
  ActiveRecord::Base.transaction do
    carts.each do |cart|
      # Проверка доступности товаров
      # Обновление контактной информации
      # Отправка заказа (draft → submitted)
      cart.submit!
    end
  end
end
```

## 📊 Форматы JSON ответов

### Корзина
```json
{
  "cart": {
    "id": 1,
    "supplier": { "id": 1, "name": "Supplier Name" },
    "items": [
      {
        "id": 1,
        "quantity": 2,
        "price_at_order": 1500.0,
        "total_price": 3000.0,
        "product": {
          "id": 123,
          "name": "Michelin Pilot Sport 4",
          "brand": "Michelin",
          "size": "225/45R17",
          "season": "summer"
        },
        "available": true
      }
    ],
    "items_count": 2,
    "total_amount": 3000.0
  }
}
```

### Заказ
```json
{
  "order": {
    "id": 1,
    "status": "submitted",
    "status_display": "Отправлен",
    "supplier": { "id": 1, "name": "Supplier Name" },
    "items_count": 2,
    "total_amount": 3000.0,
    "client_name": "Иван Иванов",
    "client_phone": "+380671234567",
    "comment": "Комментарий к заказу",
    "created_at": "05.08.2025 10:16"
  }
}
```

## ✅ Готовые функции

### Корзина
- ✅ Добавление товаров с проверкой наличия
- ✅ Изменение количества товаров
- ✅ Удаление товаров из корзины
- ✅ Очистка корзины
- ✅ Автоматическое создание корзины при первом добавлении
- ✅ Группировка по поставщикам

### Заказы
- ✅ Создание заказов из корзин
- ✅ Переходы статусов с проверкой прав
- ✅ Отмена заказов пользователями и админами
- ✅ Архивирование заказов
- ✅ Фильтрация заказов по статусу
- ✅ Поиск заказов для админов

### Безопасность
- ✅ Авторизация через JWT токены
- ✅ Политики доступа по ролям
- ✅ Пользователи видят только свои заказы
- ✅ Админы управляют всеми заказами
- ✅ Проверка прав на переходы статусов

## 🚀 Готовность к интеграции

Backend API полностью готов для интеграции с фронтендом:

1. **Все endpoint'ы реализованы** и протестированы на синтаксис
2. **Маршруты настроены** и доступны
3. **Политики авторизации** обеспечивают безопасность
4. **JSON форматы** унифицированы и документированы
5. **База данных** мигрирована и готова

## 📝 Следующие шаги

Для завершения системы необходимо:

1. **Frontend**: Модальное окно "Заказать" на `/client/tire-offers`
2. **Frontend**: Страница корзины `/client/cart`
3. **Frontend**: Индикатор корзины в навигации
4. **Frontend**: Раздел "Мои заказы" в личном кабинете
5. **Backend**: Админка для управления заказами

---

**Коммит:** `9dfccb3` - "Реализация системы заказов шин: backend API"  
**Дата:** 05.08.2025  
**Файлов изменено:** 13 (+918 строк кода)