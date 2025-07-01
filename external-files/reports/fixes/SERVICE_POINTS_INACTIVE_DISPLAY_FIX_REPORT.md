# Отчет об исправлении отображения неактивных сервисных точек в админке

## Проблема
На странице редактирования партнера `/admin/partners/1/edit` при изменении статуса сервисной точки с активного на неактивный, точка полностью исчезала из таблицы вместо того чтобы остаться с обновленным статусом.

## Диагностика

### Корневая причина
1. **Пропуск аутентификации**: Контроллер `ServicePointsController` имел `skip_before_action :authenticate_request, only: [:index, ...]`, что означало отсутствие аутентификации для метода `index`
2. **Неправильная политика**: Без аутентификации `current_user` был `nil`, поэтому применялась политика для неавторизованных пользователей (`scope.available_for_booking`)
3. **Фильтрация активных точек**: Скоуп `available_for_booking` фильтрует только активные работающие точки

### Логи диагностики
```
=== BEFORE policy_scope ===
current_user in controller:  (ID: )
current_user.admin?: 

=== DEBUG ServicePointPolicy::Scope#resolve ===
User:  ()
User.admin?: 
Applying available_for_booking scope

SQL: WHERE "service_points"."is_active" = TRUE AND "service_points"."work_status" = 'working'
```

## Исправления

### 1. ServicePointsController
**Файл**: `app/controllers/api/v1/service_points_controller.rb`

#### Убран пропуск аутентификации для index
```ruby
# БЫЛО:
skip_before_action :authenticate_request, only: [:index, :show, ...]

# СТАЛО:
skip_before_action :authenticate_request, only: [:show, :nearby, ...]
```

#### Добавлена условная аутентификация
```ruby
def index
  # Для запросов к конкретному партнеру требуем аутентификацию
  if params[:partner_id].present?
    authenticate_request unless current_user.present?
  end
  
  if params[:partner_id]
    @partner = Partner.find(params[:partner_id])
    
    # Для админов используем policy_scope(ServicePoint) с фильтрацией по партнеру
    # Для остальных используем policy_scope(@partner.service_points)
    if current_user&.admin?
      @service_points = policy_scope(ServicePoint).where(partner_id: @partner.id)
    else
      @service_points = policy_scope(@partner.service_points)
    end
  # ...
end
```

### 2. Сохранение публичного доступа
- Публичный доступ к общему списку точек (`/service_points`) сохранен
- Аутентификация требуется только для админских запросов к конкретному партнеру (`/partners/:id/service_points`)

## Результат

### До исправления
```bash
curl /api/v1/partners/1/service_points
{"data":[{"id":1,"name":"ШиноСервіс Експрес на Хрещатику","is_active":true}]}
# Только 1 активная точка
```

### После исправления
```bash
curl /api/v1/partners/1/service_points
{
  "data": [
    {"id":11,"name":"Тестовая неактивная точка 2","is_active":false},
    {"id":9,"name":"Тестовая неактивная точка","is_active":false},
    {"id":2,"name":"ШиноСервіс Експрес на Оболоні","is_active":false},
    {"id":1,"name":"ШиноСервіс Експрес на Хрещатику","is_active":true}
  ]
}
# Все 4 точки партнера (3 неактивные + 1 активная)
```

## Тестирование

### API тестирование
1. **Авторизация**: `curl -X POST /auth/login -d '{"auth":{"email":"admin@test.com","password":"admin123"}}'`
2. **Получение точек**: `curl /api/v1/partners/1/service_points --cookie cookies.txt`
3. **Изменение статуса**: `curl -X PATCH /api/v1/partners/1/service_points/2 -d '{"service_point":{"is_active":false}}'`
4. **Проверка списка**: Точка остается в списке с `is_active: false`

### Проверка политик
- **Админы**: Видят все точки партнера (активные и неактивные)
- **Партнеры**: Видят только свои точки через `by_partner` скоуп
- **Клиенты**: Видят только активные работающие точки через `available_for_booking`
- **Неавторизованные**: Публичный доступ к общему списку сохранен

## Коммиты
- **Backend**: `7afa625` - "Исправление отображения неактивных сервисных точек в админке"

## Дата
01.07.2025 