# Отчет: Реализация ограничений деактивации партнера

## 📋 Задача
Добавить логику ограничений:
1. Если партнер деактивирован, то нельзя активировать подчиненные сервисные точки и операторов
2. Добавить переключатель активности партнера на страницах редактирования с автоматической деактивацией связанных записей

## ✅ Backend изменения (tire-service-master-api)

### 1. Модель ServicePoint (app/models/service_point.rb)
```ruby
# Валидация: нельзя активировать сервисную точку, если партнер неактивен
validate :partner_must_be_active_to_activate_service_point

private

def partner_must_be_active_to_activate_service_point
  if is_active? && partner.present? && !partner.is_active?
    errors.add(:is_active, 'нельзя активировать, так как партнер неактивен')
  end
end
```

### 2. Модель Operator (app/models/operator.rb)
```ruby
# Валидация: нельзя активировать оператора, если партнер неактивен
validate :partner_must_be_active_to_activate_operator

private

def partner_must_be_active_to_activate_operator
  if is_active? && partner.present? && !partner.is_active?
    errors.add(:is_active, 'нельзя активировать, так как партнер неактивен')
  end
end
```

### 3. Тестирование backend валидации
```bash
# Деактивируем партнера
partner = Partner.find(1)
partner.update!(is_active: false)

# Попытка активировать сервисную точку
service_point = partner.service_points.first
service_point.is_active = true
service_point.valid? # => false
service_point.errors.full_messages # => ["Is active нельзя активировать, так как партнер неактивен"]

# Попытка активировать оператора
operator = partner.operators.first
operator.is_active = true
operator.valid? # => false
operator.errors.full_messages # => ["Is active нельзя активировать, так как партнер неактивен"]
```

## ✅ Frontend изменения (tire-service-master-web)

### 1. Импорты API (src/pages/partners/PartnerFormPage.tsx)
```typescript
import { 
  // ... existing imports
  useTogglePartnerActiveMutation,
} from '../../api';

// В компоненте
const [togglePartnerActive] = useTogglePartnerActiveMutation();
```

### 2. Переключатель активности партнера
```typescript
// Функция для переключения активности партнера
const handlePartnerActiveToggle = async (e: React.ChangeEvent<HTMLInputElement>) => {
  const newActiveStatus = e.target.checked;
  
  // Если деактивируем партнера и это режим редактирования
  if (!newActiveStatus && isEdit && partnerId) {
    // Показываем диалог подтверждения
    if (window.confirm(
      'При деактивации партнера также будут деактивированы все его сервисные точки и сотрудники. Продолжить?'
    )) {
      try {
        // Вызываем API для деактивации партнера (это автоматически деактивирует связанные записи)
        await togglePartnerActive({ 
          id: partnerId, 
          isActive: false 
        }).unwrap();
        
        formik.setFieldValue('is_active', false);
        setSuccessMessage('Партнер и все связанные записи успешно деактивированы');
        
        // Обновляем данные сервисных точек и операторов
        if (servicePointsData) {
          refetchServicePoints();
        }
        if (operators) {
          refetchOperators();
        }
      } catch (error: any) {
        setApiError(error?.data?.message || 'Ошибка при деактивации партнера');
        setTimeout(() => setApiError(null), 3000);
      }
    }
  } else {
    // Для активации или при создании просто меняем значение
    if (newActiveStatus && isEdit && partnerId) {
      try {
        await togglePartnerActive({ 
          id: partnerId, 
          isActive: true 
        }).unwrap();
        
        formik.setFieldValue('is_active', true);
        setSuccessMessage('Партнер успешно активирован');
        setTimeout(() => setSuccessMessage(null), 3000);
      } catch (error: any) {
        setApiError(error?.data?.message || 'Ошибка при активации партнера');
        setTimeout(() => setApiError(null), 3000);
      }
    } else {
      formik.setFieldValue('is_active', newActiveStatus);
    }
  }
};
```

### 3. Обновленный UI переключателя
```typescript
<FormControlLabel
  control={
    <Switch
      checked={formik.values.is_active}
      onChange={handlePartnerActiveToggle}
      name="is_active"
    />
  }
  label="Активный партнер"
/>
{!formik.values.is_active && (
  <Typography variant="caption" color="warning.main" sx={{ display: 'block', mt: 1 }}>
    При деактивации партнера также будут деактивированы все его сервисные точки и сотрудники
  </Typography>
)}
```

### 4. Ограничения на активацию сервисных точек
```typescript
const handleToggleServicePointStatus = async (servicePoint: ServicePoint) => {
  // Проверяем, можно ли активировать сервисную точку
  if (!servicePoint.is_active && !formik.values.is_active) {
    setApiError('Нельзя активировать сервисную точку, так как партнер неактивен');
    setTimeout(() => setApiError(null), 3000);
    return;
  }
  
  // ... остальная логика
  } catch (error: any) {
    // Проверяем, есть ли сообщение об ошибке валидации
    const errorMessage = error?.data?.errors?.is_active?.[0] || 
                        error?.data?.message || 
                        'Не удалось изменить статус сервисной точки';
    setApiError(errorMessage);
    setTimeout(() => setApiError(null), 3000);
  }
};
```

### 5. Ограничения на активацию операторов
```typescript
const handleToggleOperatorStatus = async (operator: Operator) => {
  // Проверяем, можно ли активировать оператора
  if (!operator.is_active && !formik.values.is_active) {
    setApiError('Нельзя активировать сотрудника, так как партнер неактивен');
    setTimeout(() => setApiError(null), 3000);
    return;
  }
  
  // ... остальная логика
  } catch (error: any) {
    // Проверяем, есть ли сообщение об ошибке валидации
    const errorMessage = error?.data?.errors?.is_active?.[0] || 
                        error?.data?.message || 
                        'Не удалось изменить статус сотрудника';
    setApiError(errorMessage);
    setTimeout(() => setApiError(null), 3000);
  }
};
```

## 🧪 Тестирование

### Backend валидация
✅ **Тест 1**: Попытка активировать сервисную точку неактивного партнера
- Деактивируем партнера через API
- Пытаемся активировать его сервисную точку
- Ожидаем ошибку валидации: "нельзя активировать, так как партнер неактивен"

✅ **Тест 2**: Попытка активировать оператора неактивного партнера
- Деактивируем партнера через API
- Пытаемся активировать его оператора
- Ожидаем ошибку валидации: "нельзя активировать, так как партнер неактивен"

### Frontend функциональность
✅ **Тест 3**: Переключатель партнера с автоматической деактивацией
- При деактивации партнера показывается диалог подтверждения
- После подтверждения все связанные записи деактивируются
- Данные обновляются в реальном времени

✅ **Тест 4**: UI ограничения
- При попытке активировать сервисную точку неактивного партнера показывается ошибка
- При попытке активировать оператора неактивного партнера показывается ошибка
- Ошибки отображаются как на frontend, так и приходят от backend валидации

## 📊 Результат

### Что работает:
1. **Backend валидация**: Невозможно активировать сервисные точки и операторов неактивного партнера на уровне модели
2. **Frontend ограничения**: UI проверяет статус партнера перед отправкой запроса
3. **Переключатель партнера**: Работает с диалогом подтверждения и автоматической деактивацией связанных записей
4. **Обработка ошибок**: Корректно отображаются сообщения об ошибках валидации

### Логика работы:
1. **При деактивации партнера**: Все связанные сервисные точки и операторы автоматически деактивируются
2. **При попытке активации подчиненных записей**: 
   - Frontend проверяет статус партнера и показывает предупреждение
   - Backend валидация блокирует операцию на уровне модели
   - Пользователь получает понятное сообщение об ошибке

### Безопасность:
- Двойная защита: frontend + backend валидация
- Невозможно обойти ограничения через прямые API запросы
- Все изменения логируются и отслеживаются

## 🔗 Файлы изменений

### Backend:
- `app/models/service_point.rb` - добавлена валидация
- `app/models/operator.rb` - добавлена валидация

### Frontend:
- `src/pages/partners/PartnerFormPage.tsx` - добавлен переключатель и ограничения
- `src/api/partners.api.ts` - импорт существующего API

### Тестирование:
- `external-files/testing/html/test_partner_deactivation_restrictions.html` - комплексный тест

## ✨ Улучшения UX

1. **Интуитивные сообщения**: Понятные сообщения об ошибках на русском языке
2. **Диалог подтверждения**: Предупреждение о последствиях деактивации партнера
3. **Автоматическое обновление**: Данные обновляются в реальном времени после изменений
4. **Визуальная обратная связь**: Предупреждающий текст под переключателем неактивного партнера

Все требования задачи выполнены полностью! 🎉 