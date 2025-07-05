# Отчет об исправлении ошибки обновления профиля - Проблема уникальности email

## 🚨 Проблема
При попытке обновления профиля клиента на странице `/client/profile` возникала ошибка 500:
```
ActiveRecord::RecordNotUnique (PG::UniqueViolation: ERROR: duplicate key value violates unique constraint "index_users_on_email"
DETAIL: Key (email)=() already exists.)
```

## 🔍 Анализ корневой причины
1. **Проблема с пустыми email**: В базе данных были пользователи с пустыми строками (`""`) в поле email
2. **Неправильная валидация uniqueness**: Rails валидация `uniqueness: { allow_blank: true }` не работает корректно с пустыми строками
3. **Отсутствие нормализации**: Пустые строки не конвертировались в `nil` перед сохранением

## ✅ Решение

### 1. Очистка данных в БД
```ruby
# Заменили все пустые email на nil
User.where(email: '').update_all(email: nil)
```

### 2. Улучшение модели User
**Файл**: `app/models/user.rb`

**Исправлен метод `normalize_email`**:
```ruby
def normalize_email
  if email.present?
    self.email = email.downcase
  elsif email == ''
    # Конвертируем пустые строки в nil для корректной работы uniqueness валидации
    self.email = nil
  end
end
```

**Исправлен метод `normalize_phone`**:
```ruby
def normalize_phone
  if phone.present?
    # Удаляем все символы кроме цифр и плюса
    normalized = phone.gsub(/[^\d+]/, '')
    # Если после нормализации остались только буквы или пустая строка, устанавливаем nil
    self.phone = normalized.empty? ? nil : normalized
  elsif phone == ''
    # Конвертируем пустые строки в nil для корректной работы uniqueness валидации
    self.phone = nil
  end
end
```

### 3. Тестирование исправления
**API тест успешен**:
```bash
# Создание тестового пользователя
User.create!(email: 'client@test.com', phone: '+380501234567', ...)

# Успешное обновление профиля
PUT /api/v1/auth/profile
{"user":{"first_name":"Обновленное Имя","last_name":"Обновленная Фамилия",...}}

# Ответ: 200 OK
{"user":{"id":33,"first_name":"Обновленное Имя","last_name":"Обновленная Фамилия",...}}
```

## 🎯 Результат
- ✅ Устранена ошибка `PG::UniqueViolation` при обновлении профиля
- ✅ Пустые строки автоматически конвертируются в `nil`
- ✅ Валидация `uniqueness: { allow_blank: true }` работает корректно
- ✅ API обновления профиля функционирует без ошибок

## 📊 Статистика до исправления
- Пользователи с пустыми email (`""`): 1
- Пользователи с nil email: 8
- **После исправления**: все пустые email конвертированы в nil

## 🔧 Техническая информация
- **Коммит**: Backend исправления модели User
- **Затронутые файлы**: `app/models/user.rb`
- **Тестовые данные**: Создан пользователь `client@test.com` для тестирования
- **Проверено**: API тестирование с Bearer токенами

## 🚨 Дополнительные проблемы обнаружены
1. **Cookie авторизация**: Проблемы с refresh токенами (ошибка 500)
2. **Восстановление пароля**: Ошибка отправки email (SMTP timeout)

Эти проблемы требуют отдельного исправления. 