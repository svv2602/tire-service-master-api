# Создаем шаблоны расписания для всех сервисных точек
ServicePoint.all.each do |sp|
  puts "Creating schedule for: #{sp.name}"
  
  # Понедельник-Суббота: 09:00-18:00
  (1..6).each do |day_num|
    weekday = Weekday.find_by(sort_order: day_num)
    next unless weekday
    
    ScheduleTemplate.find_or_create_by(
      service_point: sp,
      weekday: weekday
    ) do |st|
      st.is_working_day = true
      st.opening_time = Time.parse('09:00')
      st.closing_time = Time.parse('18:00')
    end
  end
  
  # Воскресенье: выходной
  sunday = Weekday.find_by(sort_order: 7)
  if sunday
    ScheduleTemplate.find_or_create_by(
      service_point: sp,
      weekday: sunday
    ) do |st|
      st.is_working_day = false
    end
  end
end

puts "Schedule templates created: #{ScheduleTemplate.count}" 