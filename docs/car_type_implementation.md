# Выбор типа автомобиля при записи на сервис

## Общее описание

При создании записи на сервис клиент может не указать конкретный свой автомобиль, но тип автомобиля (седан, внедорожник и т.д.) должен быть обязательно указан. Это необходимо для правильного планирования работ и ресурсов сервисной точки.

## Структура данных

1. Создана таблица `car_types` для хранения типов автомобилей:
   - `id` - уникальный идентификатор
   - `name` - название типа (уникальное)
   - `description` - описание типа
   - `is_active` - флаг активности
   - `created_at`, `updated_at` - метки времени

2. В таблицу `bookings` добавлено поле `car_type_id` для связи с типом автомобиля
3. В таблицу `client_cars` также добавлено поле `car_type_id` для связи с типом автомобиля

## Доступные типы автомобилей

В систему добавлены следующие типы автомобилей:
- Sedan (Седан)
- SUV (Внедорожник)
- Van (Микроавтобус)
- Pickup (Пикап)
- Hatchback (Хэтчбек)
- Estate (Универсал)
- Crossover (Кроссовер)
- Minivan (Минивэн)
- Sports car (Спорткар)

## Примеры использования

### 1. Создание бронирования с указанием только типа автомобиля

```ruby
# Находим тип автомобиля
suv_type = CarType.find_by(name: 'SUV')

# Создаем бронирование
booking = Booking.new(
  client: current_client,
  service_point: selected_service_point,
  car_type: suv_type, # Обязательно указываем тип автомобиля
  # car: nil, # Автомобиль не указан
  booking_date: selected_date,
  start_time: selected_start_time,
  end_time: selected_end_time,
  status: BookingStatus.find_by(name: 'pending'),
  # ... другие атрибуты
)

# Сохраняем бронирование
booking.save
```

### 2. Создание бронирования с указанием и автомобиля, и его типа

```ruby
# Находим автомобиль клиента
client_car = current_client.cars.find(selected_car_id)

# Создаем бронирование
booking = Booking.new(
  client: current_client,
  service_point: selected_service_point,
  car: client_car, # Указываем автомобиль клиента
  car_type: client_car.car_type || CarType.find_by(name: 'Sedan'), # Если у автомобиля не указан тип, используем Sedan по умолчанию
  booking_date: selected_date,
  start_time: selected_start_time,
  end_time: selected_end_time,
  status: BookingStatus.find_by(name: 'pending'),
  # ... другие атрибуты
)

# Сохраняем бронирование
booking.save
```

### 3. Обновление типа автомобиля для существующего автомобиля клиента

```ruby
# Находим автомобиль клиента
client_car = current_client.cars.find(car_id)

# Находим тип автомобиля
car_type = CarType.find_by(name: 'Crossover')

# Обновляем автомобиль
client_car.update(car_type: car_type)
```

## Валидации

В модели `Booking` добавлена валидация на обязательное присутствие типа автомобиля:

```ruby
validates :car_type_id, presence: true
```

Это означает, что бронирование не может быть создано без указания типа автомобиля, даже если конкретный автомобиль не выбран.
