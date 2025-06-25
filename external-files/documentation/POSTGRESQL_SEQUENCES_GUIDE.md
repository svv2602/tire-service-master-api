# 🔧 Руководство по последовательностям PostgreSQL в Rails

## 🚨 Проблема: PG::UniqueViolation - duplicate key value violates unique constraint

### Что происходит?
```
PG::UniqueViolation: ERROR: duplicate key value violates unique constraint "regions_pkey"
DETAIL: Key (id)=(2) already exists.
```

## 🔍 Причины возникновения

### 1. **Импорт данных с явными ID**
```sql
-- ❌ НЕПРАВИЛЬНО - нарушает последовательность
INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@test.com');
INSERT INTO users (id, name, email) VALUES (50, 'Jane', 'jane@test.com');
-- Последовательность users_id_seq остается на 1, но в таблице уже есть ID=50
```

### 2. **Восстановление из бэкапов**
```sql
-- При восстановлении данных из дампа PostgreSQL
-- последовательности могут не синхронизироваться с данными
```

### 3. **Ручное вмешательство в данные**
```sql
-- Прямые SQL запросы с указанием ID
-- Копирование данных между базами
-- Миграции с фиксированными ID
```

### 4. **Параллельные операции**
```ruby
# Одновременное создание записей в многопоточной среде
# может привести к конфликтам последовательностей
```

## 🛠️ Решения

### 1. **Быстрое исправление (наш случай)**
```ruby
# Rails runner скрипт для исправления всех последовательностей
rails runner "
tables = %w[regions cities users clients partners bookings service_points reviews]

tables.each do |table|
  begin
    max_id = ActiveRecord::Base.connection.execute(\"SELECT MAX(id) FROM #{table}\").first['max'] || 0
    sequence_name = \"#{table}_id_seq\"
    
    ActiveRecord::Base.connection.execute(\"SELECT setval('#{sequence_name}', #{max_id + 1})\")
    puts \"✅ #{table}: установлена последовательность на #{max_id + 1}\"
  rescue => e
    puts \"❌ Ошибка для #{table}: #{e.message}\"
  end
end
"
```

### 2. **Исправление через SQL**
```sql
-- Для конкретной таблицы
SELECT setval('regions_id_seq', COALESCE((SELECT MAX(id) FROM regions), 1));

-- Для всех таблиц сразу
SELECT setval('regions_id_seq', COALESCE((SELECT MAX(id) FROM regions), 1));
SELECT setval('cities_id_seq', COALESCE((SELECT MAX(id) FROM cities), 1));
SELECT setval('users_id_seq', COALESCE((SELECT MAX(id) FROM users), 1));
```

### 3. **Rake задача для автоматизации**
```ruby
# lib/tasks/sequences.rake
namespace :db do
  desc "Исправление последовательностей PostgreSQL"
  task fix_sequences: :environment do
    tables = %w[regions cities users clients partners bookings service_points reviews]
    
    puts "🔧 Исправление последовательностей PostgreSQL..."
    
    tables.each do |table|
      begin
        max_id = ActiveRecord::Base.connection.execute(
          "SELECT MAX(id) FROM #{table}"
        ).first['max'] || 0
        
        sequence_name = "#{table}_id_seq"
        next_val = max_id + 1
        
        ActiveRecord::Base.connection.execute(
          "SELECT setval('#{sequence_name}', #{next_val})"
        )
        
        puts "✅ #{table.ljust(20)} -> #{next_val}"
      rescue => e
        puts "❌ #{table.ljust(20)} -> Ошибка: #{e.message}"
      end
    end
    
    puts "🎉 Готово!"
  end
end
```

## 🛡️ Профилактика

### 1. **Правильные Seeds**
```ruby
# ✅ ПРАВИЛЬНО - позволяем PostgreSQL генерировать ID
regions_data.each do |region_data|
  region = Region.find_or_create_by(name: region_data[:name]) do |r|
    r.code = region_data[:code]
    r.is_active = true
  end
end

# ❌ НЕПРАВИЛЬНО - не указываем ID вручную
Region.create!(id: 1, name: "Київська область")
```

### 2. **Безопасные миграции**
```ruby
# ✅ ПРАВИЛЬНО - используем Rails методы
class CreateRegions < ActiveRecord::Migration[7.0]
  def change
    create_table :regions do |t|
      t.string :name, null: false
      t.string :code
      t.boolean :is_active, default: true
      t.timestamps
    end
  end
end

# ❌ ИЗБЕГАТЬ - прямой SQL с ID
def up
  execute "INSERT INTO regions (id, name) VALUES (1, 'Test')"
end
```

### 3. **Проверка после импорта**
```ruby
# После любого импорта данных
def self.fix_sequences!
  connection.tables.each do |table|
    next unless connection.column_exists?(table, :id)
    
    max_id = connection.select_value("SELECT MAX(id) FROM #{table}") || 0
    sequence_name = "#{table}_id_seq"
    
    connection.execute("SELECT setval('#{sequence_name}', #{max_id + 1})")
  end
end
```

### 4. **Мониторинг последовательностей**
```ruby
# Проверка состояния последовательностей
def self.check_sequences
  connection.tables.each do |table|
    next unless connection.column_exists?(table, :id)
    
    max_id = connection.select_value("SELECT MAX(id) FROM #{table}") || 0
    sequence_name = "#{table}_id_seq"
    current_val = connection.select_value("SELECT currval('#{sequence_name}')")
    
    if current_val <= max_id
      puts "⚠️  #{table}: последовательность #{current_val}, максимальный ID #{max_id}"
    else
      puts "✅ #{table}: OK"
    end
  end
end
```

## 🔄 Автоматизация

### 1. **Добавление в deploy процесс**
```ruby
# config/deploy.rb (Capistrano)
after 'deploy:migrate', 'deploy:fix_sequences'

namespace :deploy do
  task :fix_sequences do
    on roles(:app) do
      within release_path do
        execute :rake, 'db:fix_sequences'
      end
    end
  end
end
```

### 2. **Проверка в тестах**
```ruby
# spec/support/database_sequences.rb
RSpec.configure do |config|
  config.after(:suite) do
    DatabaseSequences.check_and_fix_all
  end
end
```

## 📊 Диагностика

### Проверка текущего состояния
```sql
-- Проверка последовательности
SELECT currval('regions_id_seq');
SELECT MAX(id) FROM regions;

-- Информация о последовательности
SELECT * FROM pg_sequences WHERE sequencename = 'regions_id_seq';
```

### Проверка всех последовательностей
```sql
SELECT 
  schemaname,
  sequencename,
  last_value,
  (SELECT MAX(id) FROM regions) as max_table_id
FROM pg_sequences 
WHERE sequencename LIKE '%_id_seq';
```

## 🎯 Лучшие практики

1. **Никогда не указывайте ID вручную** в production данных
2. **Используйте find_or_create_by** вместо create с ID
3. **Проверяйте последовательности** после любого импорта
4. **Автоматизируйте исправление** через rake задачи
5. **Мониторьте состояние** в CI/CD процессе

## 🚀 Итог

Проблема с последовательностями PostgreSQL решается просто, но лучше **предотвращать** её правильным подходом к созданию данных. Всегда используйте Rails методы и избегайте ручного указания ID. 