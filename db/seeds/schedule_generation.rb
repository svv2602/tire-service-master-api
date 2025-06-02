# db/seeds/schedule_generation.rb
# Создание шаблонов расписания для динамической системы доступности

puts 'Creating schedule templates for dynamic availability system...'

# Проверяем, что у нас есть точки обслуживания и посты
if ServicePoint.count.zero?
  puts "  No service points found, please run service_points seed first"
  return
end

if ServicePost.count.zero?
  puts "  No service posts found, please run service_points seed first"
  return
end

# Создаем дни недели если их нет
if Weekday.count == 0
  puts "  Creating weekdays..."
  
  weekdays_data = [
    { name: "Понедельник", sort_order: 1 },
    { name: "Вторник", sort_order: 2 },
    { name: "Среда", sort_order: 3 },
    { name: "Четверг", sort_order: 4 },
    { name: "Пятница", sort_order: 5 },
    { name: "Суббота", sort_order: 6 },
    { name: "Воскресенье", sort_order: 7 }
  ]
  
  weekdays_data.each do |day_data|
    Weekday.create!(day_data)
  end
  
  puts "    Created #{Weekday.count} weekdays"
end

puts "  Creating schedule templates for service points..."

ServicePoint.all.each do |service_point|
  puts "  Processing #{service_point.name}..."
  
  # Создаем базовые шаблоны расписания для всех дней недели
  (1..7).each do |day_number|
    weekday = Weekday.find_by(sort_order: day_number)
    next unless weekday
    
    template = ScheduleTemplate.find_or_initialize_by(
      service_point: service_point,
      weekday: weekday
    )
    
    if template.new_record?
      # Рабочие дни: понедельник-суббота (воскресенье - выходной)
      is_working = day_number < 7
      
      template.assign_attributes(
        is_working_day: is_working,
        opening_time: is_working ? '09:00:00' : nil,
        closing_time: is_working ? '18:00:00' : nil
      )
      
      template.save!
      puts "    Created schedule template for #{weekday.name} (#{is_working ? 'рабочий' : 'выходной'})"
    else
      puts "    Template for #{weekday.name} already exists"
    end
  end
  
  # Выводим сводку по рабочим часам
  working_templates = service_point.schedule_templates.where(is_working_day: true)
  puts "    Рабочих дней: #{working_templates.count}, посты: #{service_point.posts_count}"
end

puts "\nSchedule templates creation completed!"
puts "  Total service points: #{ServicePoint.count}"
puts "  Total active posts: #{ServicePost.active.count}"
puts "  Total schedule templates: #{ScheduleTemplate.count}"

# Выводим сводку по рабочим часам каждой точки
puts "\nWorking hours summary:"
ServicePoint.includes(:schedule_templates).each do |sp|
  puts "  #{sp.name} (#{sp.posts_count} постов):"
  sp.schedule_templates.joins(:weekday).order('weekdays.sort_order').each do |template|
    if template.is_working_day
      puts "    #{template.weekday.name}: #{template.opening_time.strftime('%H:%M')} - #{template.closing_time.strftime('%H:%M')}"
    else
      puts "    #{template.weekday.name}: выходной"
    end
  end
  puts ""
end

puts "\nДинамическая система доступности готова к работе!"
puts "Теперь можно использовать API для получения доступных времен без генерации слотов." 