# db/seeds/schedule_generation.rb
# Создание шаблонов расписания для динамической системы доступности

puts 'Creating schedule templates for dynamic availability system...'

# Проверка, не были ли уже созданы шаблоны расписания
if ScheduleTemplate.count > 0
  puts "  Schedule templates already exist (#{ScheduleTemplate.count} found), skipping creation"
  puts "  If you want to recreate schedule templates, run reset_db.sh script"
  return
end

# Очищаем существующие шаблоны
ScheduleTemplate.destroy_all
puts "  Cleared existing schedule templates"

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
    { name: "Понедельник", short_name: "Пн", sort_order: 1 },
    { name: "Вторник", short_name: "Вт", sort_order: 2 },
    { name: "Среда", short_name: "Ср", sort_order: 3 },
    { name: "Четверг", short_name: "Чт", sort_order: 4 },
    { name: "Пятница", short_name: "Пт", sort_order: 5 },
    { name: "Суббота", short_name: "Сб", sort_order: 6 },
    { name: "Воскресенье", short_name: "Вс", sort_order: 7 }
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
        opening_time: is_working ? '09:00:00' : '00:00:00',
        closing_time: is_working ? '18:00:00' : '23:59:59'
      )
      
      begin
      template.save!
      puts "    Created schedule template for #{weekday.name} (#{is_working ? 'рабочий' : 'выходной'})"
      rescue ActiveRecord::RecordInvalid => e
        puts "    Error creating template for #{weekday.name}: #{e.message}"
        # Для выходных дней попробуем создать с минимальными значениями
        if !is_working
          template.opening_time = '00:00:00'
          template.closing_time = '00:00:00'
          template.save!
          puts "    Created template for #{weekday.name} with default times"
        end
      end
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

# Обновляем поле working_hours в таблице service_points
puts "\nUpdating working_hours for service points..."
ServicePoint.find_each do |service_point|
  service_point.update_working_hours_from_templates
  puts "  Updated working_hours for #{service_point.name}"
end

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