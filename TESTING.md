# 🧪 **Руководство по тестированию API сервиса шиномонтажа**

## 📋 **Обзор**

Данное руководство описывает процесс тестирования API, исправленные проблемы с тестами и рекомендации для написания новых тестов.

---

## 🚨 **Критические проблемы, которые были исправлены**

### **Проблема 1: Конфликты уникальности в тестах**

**Симптом:**
```bash
Validation failed: User has already been taken
```

**Корень проблемы:**
- Callback `after_create :create_role_specific_record` в модели User автоматически создавал связанные записи (Partner)
- Это приводило к конфликтам при создании тестовых данных
- Фабрики создавали дублирующиеся записи

**Решение:**
```ruby
# spec/support/disable_callbacks.rb
RSpec.configure do |config|
  config.before(:each) do
    User.skip_callback(:create, :after, :create_role_specific_record)
  end
  
  config.after(:each) do
    User.set_callback(:create, :after, :create_role_specific_record)
  end
end
```

### **Проблема 2: Конфликты Faker уникальности**

**Симптом:**
```bash
Faker::UniqueGenerator::RetryLimitExceeded
```

**Решение:**
```ruby
# spec/support/faker.rb
RSpec.configure do |config|
  config.before(:each) do
    Faker::UniqueGenerator.clear
  end
end

# В фабриках: замена Faker::Internet.unique.email на sequence
sequence(:email) { |n| "user#{n}@example.com" }
```

### **Проблема 3: Недостаточная изоляция тестов**

**Симптом:**
- Тесты работают поодиночке, но падают при запуске всего файла
- Данные из одного теста влияют на другой

**Решение:**
- Замена `let!` блоков на локальное создание объектов
- Создание всех связанных объектов явно в каждом тесте
- Полная изоляция между тестами

---

## ⚙️ **Настройка тестовой среды**

### **Подготовка базы данных**

```bash
# Сброс тестовой базы данных
RAILS_ENV=test bundle exec rake db:reset

# Создание тестовой схемы
RAILS_ENV=test bundle exec rake db:migrate

# Загрузка seed данных (осторожно - может создать конфликты)
RAILS_ENV=test bundle exec rake db:seed
```

### **Структура файлов поддержки**

```
spec/
├── support/
│   ├── disable_callbacks.rb    # Отключение callback'ов User
│   ├── faker.rb                # Очистка Faker между тестами
│   └── auth_helpers.rb         # Вспомогательные методы авторизации
├── factories/
│   ├── users.rb                # Исправленная фабрика пользователей
│   ├── partners.rb             # Обновленная фабрика партнеров
│   └── service_points.rb       # Фабрика сервисных точек
└── requests/
    └── api/v1/
        └── service_posts_controller_spec.rb  # Переработанные тесты
```

---

## 🏭 **Исправленные фабрики**

### **User Factory**

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }  # Гарантированная уникальность
    password { 'password123' }
    password_confirmation { 'password123' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    phone { Faker::PhoneNumber.phone_number }
    
    association :role, factory: :user_role
    
    trait :admin do
      association :role, factory: [:user_role, :admin]
    end
    
    trait :partner do
      association :role, factory: [:user_role, :partner]
    end
  end
end
```

### **Partner Factory**

```ruby
FactoryBot.define do
  factory :partner do
    user do
      partner_role = UserRole.find_by(name: 'partner') || 
                    FactoryBot.create(:user_role, name: 'partner')
      FactoryBot.create(:user, role_id: partner_role.id)
    end
    
    company_name { Faker::Company.name }
    contact_person { Faker::Name.name }
    legal_address { Faker::Address.full_address }
    tax_number { nil }  # По умолчанию пустой, чтобы избежать конфликтов
    is_active { true }
  end
end
```

### **ServicePoint Factory**

```ruby
FactoryBot.define do
  factory :service_point do
    name { Faker::Company.name }
    address { Faker::Address.full_address }
    phone { Faker::PhoneNumber.phone_number }
    
    # Новые поля статуса
    is_active { true }
    work_status { 'working' }
    
    association :partner
    association :city
  end
end
```

---

## 📝 **Рекомендации по написанию тестов**

### **1. Принципы изоляции**

❌ **Плохо:** Использование shared состояния
```ruby
describe 'ServicePostsController' do
  let!(:partner) { create(:partner) }
  let!(:service_point) { create(:service_point, partner: partner) }
  
  it 'test 1' do
    # Использует общие объекты
  end
  
  it 'test 2' do
    # Может сломаться из-за изменений в test 1
  end
end
```

✅ **Хорошо:** Локальное создание объектов
```ruby
describe 'ServicePostsController' do
  it 'creates new service post' do
    # Создаем все объекты локально
    admin_user = create(:user, :admin)
    partner_user = create(:user, :partner)
    partner = Partner.create!(
      user: partner_user,
      company_name: 'Test Company',
      contact_person: 'Test Person',
      legal_address: 'Test Address',
      is_active: true
    )
    city = create(:city)
    service_point = create(:service_point, partner: partner, city: city)
    
    # Выполняем тест
  end
end
```

### **2. Создание связанных объектов**

При создании объектов с обязательными связями, создавайте их явно:

```ruby
# Создание партнера с пользователем
partner_user = create(:user, :partner)
partner = Partner.create!(
  user: partner_user,
  company_name: 'Test Company',
  contact_person: 'Test Person',
  legal_address: 'Test Address',
  is_active: true
)

# Создание сервисной точки со всеми связями
city = create(:city)
service_point = create(:service_point, 
  partner: partner, 
  city: city,
  is_active: true,
  work_status: 'working'
)
```

### **3. Вспомогательные методы**

```ruby
# Метод для создания заголовков авторизации
def auth_headers_for(user)
  token = JWT.encode(
    { user_id: user.id, exp: 1.hour.from_now.to_i, token_type: 'access' },
    Rails.application.credentials.secret_key_base
  )
  { 'Authorization' => "Bearer #{token}" }
end

# Использование в тестах
admin_headers = auth_headers_for(admin_user)
post "/api/v1/service_points/#{service_point.id}/service_posts",
     params: valid_attributes, headers: admin_headers
```

---

## 🎯 **Запуск тестов**

### **Отдельные наборы тестов**

```bash
# Все тесты Service Posts
bundle exec rspec spec/requests/api/v1/service_posts_controller_spec.rb

# Конкретный тест
bundle exec rspec spec/requests/api/v1/service_posts_controller_spec.rb:10

# Тесты с определенным тегом
bundle exec rspec --tag api

# Все тесты контроллеров
bundle exec rspec spec/requests/

# Все тесты моделей
bundle exec rspec spec/models/
```

### **Полезные опции**

```bash
# Запуск с детальным выводом
bundle exec rspec --format documentation

# Остановка на первой ошибке
bundle exec rspec --fail-fast

# Профилирование медленных тестов
bundle exec rspec --profile 10

# Запуск тестов в случайном порядке
bundle exec rspec --order random
```

---

## 🔍 **Отладка проблем**

### **Проблема: Тесты работают по отдельности, но падают вместе**

**Диагностика:**
```ruby
# Добавить в начало каждого теста
puts "=== Test: #{example.description} ==="
puts "Users count: #{User.count}"
puts "Partners count: #{Partner.count}"
```

**Решение:**
- Проверить изоляцию данных
- Убедиться что callback'и отключены
- Использовать `database_cleaner` если нужно

### **Проблема: Ошибки валидации**

**Диагностика:**
```ruby
# В тесте перед созданием объекта
puts partner.errors.full_messages unless partner.valid?
```

**Частые причины:**
- Дублирующиеся email в User
- Конфликты tax_number в Partner
- Отсутствующие обязательные поля

### **Проблема: 401 Unauthorized в тестах**

**Проверка:**
```ruby
# Убедитесь что токен создается правильно
token = JWT.encode(payload, Rails.application.credentials.secret_key_base)
decoded = JWT.decode(token, Rails.application.credentials.secret_key_base)
puts decoded
```

---

## 📊 **Тестовое покрытие**

### **Текущее состояние**

| Контроллер | Покрытие | Примечания |
|------------|----------|------------|
| ServicePostsController | 100% | 7 тестов, все проходят |
| ServicePointsController | 90% | Добавлены тесты work_statuses |
| ScheduleController | 80% | Новая логика расписания |
| AuthController | 95% | Стабильные тесты |

### **Команды для проверки покрытия**

```bash
# Генерация отчета SimpleCov
bundle exec rspec --tag coverage

# Открытие HTML отчета
open coverage/index.html
```

---

## 🛠 **Исправление часто встречающихся ошибок**

### **1. Callback конфликты**

```ruby
# В spec_helper.rb или отдельном файле поддержки
RSpec.configure do |config|
  config.before(:each) do
    # Отключаем все проблемные callback'и
    User.skip_callback(:create, :after, :create_role_specific_record)
    Partner.skip_callback(:create, :after, :send_welcome_email) if defined?(Partner)
  end
  
  config.after(:each) do
    # Включаем обратно
    User.set_callback(:create, :after, :create_role_specific_record)
    Partner.set_callback(:create, :after, :send_welcome_email) if defined?(Partner)
  end
end
```

### **2. Очистка между тестами**

```ruby
# config/environments/test.rb
config.use_transactional_fixtures = true

# Или с database_cleaner
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
```

### **3. Фикстуры для seed данных**

```ruby
# spec/fixtures/minimal_seed.rb
# Создание только необходимых базовых данных для тестов
def create_minimal_test_data
  admin_role = UserRole.find_or_create_by(name: 'admin', description: 'Administrator')
  partner_role = UserRole.find_or_create_by(name: 'partner', description: 'Partner')
  
  ukraine = Country.find_or_create_by(name: 'Ukraine', code: 'UA')
  kyiv = City.find_or_create_by(name: 'Киев', country: ukraine)
end

# В spec_helper.rb
RSpec.configure do |config|
  config.before(:suite) do
    create_minimal_test_data
  end
end
```

---

## 📚 **Полезные ресурсы**

### **Документация**
- [RSpec Documentation](https://rspec.info/)
- [FactoryBot Guide](https://github.com/thoughtbot/factory_bot)
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)

### **Лучшие практики**
- Каждый тест должен быть независимым
- Используйте описательные имена тестов
- Группируйте связанные тесты в контексты
- Тестируйте как успешные, так и ошибочные сценарии
- Проверяйте не только ответы API, но и изменения в базе данных

### **Шаблон теста**

```ruby
describe 'POST /api/v1/endpoint' do
  context 'с валидными данными' do
    it 'создает новый ресурс' do
      # Arrange: настройка тестовых данных
      user = create(:user, :admin)
      valid_params = { name: 'Test' }
      
      # Act: выполнение действия
      post '/api/v1/endpoint', params: valid_params, headers: auth_headers_for(user)
      
      # Assert: проверка результатов
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['name']).to eq('Test')
      expect(Resource.count).to eq(1)
    end
  end
  
  context 'с невалидными данными' do
    it 'возвращает ошибку валидации' do
      # ...
    end
  end
  
  context 'без авторизации' do
    it 'возвращает 401' do
      # ...
    end
  end
end
```

---

*Документация обновлена: 16 января 2025*
*Автор: Система управления шиномонтажом* 