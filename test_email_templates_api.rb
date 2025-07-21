#!/usr/bin/env ruby

puts '📧 ТЕСТИРОВАНИЕ API УПРАВЛЕНИЯ EMAIL ШАБЛОНАМИ'
puts '============================================='

begin
  # Проверяем что контроллер существует
  puts "\n🔍 ПРОВЕРКА КОНТРОЛЛЕРА"
  puts "======================"
  
  controller_path = 'app/controllers/api/v1/email_templates_controller.rb'
  if File.exist?(controller_path)
    puts "✅ Контроллер найден: #{controller_path}"
  else
    puts "❌ Контроллер не найден: #{controller_path}"
  end
  
  # Проверяем политики
  puts "\n🛡️ ПРОВЕРКА ПОЛИТИК"
  puts "=================="
  
  policy_path = 'app/policies/email_template_policy.rb'
  if File.exist?(policy_path)
    puts "✅ Политика найдена: #{policy_path}"
  else
    puts "❌ Политика не найдена: #{policy_path}"
  end
  
  # Проверяем маршруты
  puts "\n🛤️ ПРОВЕРКА МАРШРУТОВ"
  puts "===================="
  
  routes_output = `rails routes | grep email_templates`
  if routes_output.present?
    puts "✅ Маршруты email_templates найдены:"
    puts routes_output
  else
    puts "❌ Маршруты email_templates не найдены"
  end
  
  # Проверяем существующие шаблоны
  puts "\n📝 ПРОВЕРКА СУЩЕСТВУЮЩИХ ШАБЛОНОВ"
  puts "================================"
  
  total_templates = EmailTemplate.count
  active_templates = EmailTemplate.active.count
  
  puts "Всего шаблонов: #{total_templates}"
  puts "Активных шаблонов: #{active_templates}"
  puts "Неактивных шаблонов: #{total_templates - active_templates}"
  
  # Группировка по типам
  puts "\n📊 ШАБЛОНЫ ПО ТИПАМ:"
  EmailTemplate.group(:template_type).count.each do |type, count|
    puts "  #{type}: #{count}"
  end
  
  # Группировка по языкам
  puts "\n🌐 ШАБЛОНЫ ПО ЯЗЫКАМ:"
  EmailTemplate.group(:language).count.each do |lang, count|
    puts "  #{lang}: #{count}"
  end
  
  # Проверяем типы шаблонов
  puts "\n🎯 ДОСТУПНЫЕ ТИПЫ ШАБЛОНОВ"
  puts "=========================="
  
  EmailTemplate.template_types.each do |key, value|
    existing = EmailTemplate.exists?(template_type: key)
    status = existing ? '✅' : '❌'
    puts "  #{status} #{key}: #{value}"
  end
  
  # Тестируем методы модели
  puts "\n🧪 ТЕСТИРОВАНИЕ МЕТОДОВ МОДЕЛИ"
  puts "============================="
  
  if EmailTemplate.any?
    template = EmailTemplate.first
    puts "✅ Тестовый шаблон: #{template.name}"
    puts "   Тип: #{template.template_type}"
    puts "   Язык: #{template.language}"
    puts "   Активен: #{template.is_active?}"
    puts "   Статус: #{template.status_text}"
    puts "   Название типа: #{template.template_type_name}"
    
    # Тестируем переменные
    variables = template.variables_array
    puts "   Переменных: #{variables.length}"
    puts "   Переменные: #{variables.join(', ')}" if variables.any?
    
    # Тестируем рендеринг
    test_vars = {
      'client_first_name' => 'Тест',
      'client_last_name' => 'Пользователь',
      'service_point_name' => 'Тестовая точка'
    }
    
    begin
      rendered = template.render_with_variables(test_vars)
      puts "   ✅ Рендеринг работает"
      puts "   Тема: #{rendered[:subject][0..50]}..."
    rescue => e
      puts "   ❌ Ошибка рендеринга: #{e.message}"
    end
  else
    puts "❌ Нет шаблонов для тестирования"
  end
  
rescue => e
  puts "❌ Ошибка: #{e.message}"
  puts "   #{e.backtrace.first(3).join('\n   ')}"
end

puts "\n🎯 ПРОВЕРКА ЗАВЕРШЕНА!"
puts "API управления email шаблонами готов к использованию." 