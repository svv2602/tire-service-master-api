#!/usr/bin/env ruby

# Добавляем путь к приложению
require_relative 'config/environment'

# Устанавливаем тестовое окружение
Rails.env = 'test'

puts "=== Отладка удаления ServiceCategory ==="
puts "Rails.env: #{Rails.env}"

# Создаем тестовую категорию
category = ServiceCategory.new(name: "Test Category #{Time.current.to_i}")
puts "Создали категорию: #{category.name}"

if category.save
  puts "Категория сохранена с ID: #{category.id}"
  
  # Проверяем количество услуг
  services_count = category.services.count
  puts "Количество услуг в категории: #{services_count}"
  
  # Пытаемся удалить
  puts "Пытаемся удалить категорию..."
  
  begin
    result = category.destroy
    if result
      puts "Категория успешно удалена"
      puts "category.destroyed?: #{category.destroyed?}"
    else
      puts "Удаление не удалось"
      puts "Ошибки: #{category.errors.full_messages}"
    end
  rescue => e
    puts "Исключение при удалении: #{e.class} - #{e.message}"
    puts e.backtrace.first(5)
  end
else
  puts "Не удалось сохранить категорию: #{category.errors.full_messages}"
end

puts "\n=== Проверка подключений в базе данных ==="

# Проверяем внешние ключи на таблицу service_categories
result = ActiveRecord::Base.connection.execute(<<-SQL)
  SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
  FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
  WHERE 
    tc.constraint_type = 'FOREIGN KEY' AND
    ccu.table_name = 'service_categories';
SQL

puts "Внешние ключи ссылающиеся на service_categories:"
result.each do |row|
  puts "  #{row['table_name']}.#{row['column_name']} -> #{row['foreign_table_name']}.#{row['foreign_column_name']}"
end
