# 🔧 ОТЧЕТ: Исправление MUI ошибки "out-of-range value" в селекте партнеров

## 📋 Проблема

### MUI ошибка селекта
```
MUI: You have provided an out-of-range value `6` for the select (name="partner_id") component.
Consider providing a value that matches one of the available options or ''.
The available values are `8`, `9`, `7`.
```

### Анализ проблемы
- **Форма устанавливает:** `partner_id = 6` (из договоренности)
- **API возвращает партнеров:** ID `8`, `9`, `7`
- **Партнер ID=6 отсутствует** в списке доступных опций

### Корневая причина
API `/agreements/partners` возвращал только **активных** партнеров (`Partner.active`), но договоренность может ссылаться на **неактивного** партнера.

## 🛠️ Решения

### 1. Обновление API /agreements/partners

**Файл:** `tire-service-master-api/app/controllers/api/v1/agreements_controller.rb`

**Добавлен параметр фильтрации:**
```ruby
# GET /api/v1/agreements/partners
def partners
  authorize PartnerSupplierAgreement, :index?
  
  # Включаем всех партнеров для редактирования существующих договоренностей
  # Параметр only_active=true для создания новых договоренностей
  if params[:only_active] == 'true'
    @partners = Partner.active.includes(:user).order(:company_name)
  else
    @partners = Partner.includes(:user).order(:company_name)  # ВСЕ партнеры
  end
  
  render json: {
    data: @partners.map { |partner|
      {
        id: partner.id,
        company_name: partner.company_name,
        contact_person: partner.contact_person,
        phone: partner.user&.phone || '',
        is_active: partner.is_active?  # Статус активности
      }
    }
  }
end
```

### 2. Отдельный endpoint для активных партнеров

**Файл:** `tire-service-master-web/src/api/agreements.api.ts`

**Добавлен новый хук:**
```typescript
// Получение списка партнеров для селекта (все партнеры для редактирования)
getAgreementPartners: builder.query<ApiResponse<PartnerOption[]>, void>({
  query: () => 'agreements/partners',
  providesTags: ['AgreementPartner'],
}),

// Получение только активных партнеров для создания новых договоренностей
getActiveAgreementPartners: builder.query<ApiResponse<PartnerOption[]>, void>({
  query: () => 'agreements/partners?only_active=true',
  providesTags: ['AgreementPartner'],
}),
```

### 3. Улучшение UI селекта партнеров

**Файл:** `tire-service-master-web/src/pages/agreements/AgreementEditPage.tsx`

**Визуальное отображение статуса:**
```tsx
{partners.map((partner) => (
  <MenuItem 
    key={partner.id} 
    value={partner.id}
    sx={{ 
      opacity: partner.is_active ? 1 : 0.6,
      fontStyle: partner.is_active ? 'normal' : 'italic'
    }}
  >
    {partner.company_name} ({partner.contact_person})
    {!partner.is_active && <span style={{ color: '#f44336', marginLeft: '8px' }}>[НЕАКТИВЕН]</span>}
  </MenuItem>
))}
```

### 4. Разделение логики по страницам

**Страница редактирования:** `AgreementEditPage.tsx`
- Использует `useGetAgreementPartnersQuery()` - **ВСЕ** партнеры
- Показывает неактивных партнеров с пометкой
- Позволяет отображать текущего партнера договоренности

**Страница создания:** `AgreementCreatePage.tsx`  
- Использует `useGetActiveAgreementPartnersQuery()` - только **АКТИВНЫЕ**
- Предотвращает создание договоренностей с неактивными партнерами

## 📊 Логика работы

### Сценарий 1: Редактирование существующей договоренности
1. ✅ Загружаются **ВСЕ** партнеры (активные + неактивные)
2. ✅ Форма находит партнера ID=6 в списке
3. ✅ MUI селект отображается корректно
4. ✅ Неактивные партнеры помечены как `[НЕАКТИВЕН]`

### Сценарий 2: Создание новой договоренности
1. ✅ Загружаются только **АКТИВНЫЕ** партнеры
2. ✅ Список содержит только валидные для новых договоренностей партнеры
3. ✅ Предотвращается создание с неактивными партнерами

## 🧪 Тестирование

### Создан тестовый файл
**Файл:** `tire-service-master-web/external-files/testing/html/test_partner_select_fix.html`

**Проверяет:**
1. **API все партнеры:** `GET /agreements/partners`
2. **API активные:** `GET /agreements/partners?only_active=true`
3. **Договоренность ID=2:** `GET /agreements/2`
4. **Анализ данных:** наличие партнера ID=6 в разных запросах

### Ожидаемые результаты
```bash
# Все партнеры (включая неактивных)
GET /agreements/partners
Response: {data: [{id: 6, is_active: false}, {id: 7, is_active: true}, ...]}

# Только активные партнеры  
GET /agreements/partners?only_active=true
Response: {data: [{id: 7, is_active: true}, {id: 8, is_active: true}, ...]}
```

## 📱 UX улучшения

### Визуальные индикаторы
- **Активные партнеры:** обычный текст, полная непрозрачность
- **Неактивные партнеры:** курсив, 60% непрозрачность, красная пометка `[НЕАКТИВЕН]`

### Поведение селекта
- **При редактировании:** можно видеть и сохранить неактивного партнера
- **При создании:** только активные партнеры в списке
- **MUI ошибки устранены:** все значения имеют соответствующие опции

## 🔄 Результаты исправления

### ✅ MUI ошибка устранена
- Партнер ID=6 теперь присутствует в списке опций
- Селект корректно отображает выбранное значение
- Нет ошибок "out-of-range value"

### ✅ Улучшен UX
- Визуально видны неактивные партнеры
- Понятно, почему партнер недоступен для новых договоренностей
- Сохранена возможность редактировать существующие договоренности

### ✅ Разделена логика
- Создание: только активные партнеры
- Редактирование: все партнеры с пометками
- API поддерживает оба сценария

### ✅ Обратная совместимость
- Существующие договоренности отображаются корректно
- API изменения не ломают другие части системы
- TypeScript типы обновлены

---

**Статус:** ✅ ИСПРАВЛЕНО  
**Дата:** 2025-08-09  
**Файлы изменены:** 3  
**Тесты созданы:** 1

**Ключевые изменения:**
- API поддержка фильтрации партнеров по активности
- UI индикация статуса партнеров  
- Разделение логики создания/редактирования
- Устранение MUI ошибок селекта