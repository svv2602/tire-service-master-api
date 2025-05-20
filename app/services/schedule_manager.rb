class ScheduleManager
  # Генерирует слоты расписания на указанную дату для указанной сервисной точки
  def self.generate_slots_for_date(service_point_id, date)
    service_point = ServicePoint.find(service_point_id)
    weekday = Weekday.find_by(day_number: date.wday)
    
    # Проверяем, если на указанную дату есть исключение из расписания
    exception = ScheduleException.find_by(service_point_id: service_point_id, exception_date: date)
    
    if exception
      if exception.is_working_day
        # Для рабочего дня исключения используем особое расписание
        generate_slots_from_exception(service_point, date, exception)
      else
        # Для нерабочего дня просто удаляем все существующие неиспользуемые слоты
        delete_unused_slots(service_point_id, date)
      end
      return
    end
    
    # Находим шаблон расписания для указанного дня недели
    template = ScheduleTemplate.find_by(service_point_id: service_point_id, weekday_id: weekday.id)
    
    # Если шаблона нет или день нерабочий, удаляем все неиспользуемые слоты и выходим
    if template.nil? || !template.is_working_day
      delete_unused_slots(service_point_id, date)
      return
    end
    
    # Генерируем слоты на основе шаблона
    generate_slots_from_template(service_point, date, template)
  end
  
  # Генерирует слоты расписания на указанный период для указанной сервисной точки
  def self.generate_slots_for_period(service_point_id, start_date, end_date)
    (start_date..end_date).each do |date|
      generate_slots_for_date(service_point_id, date)
    end
  end
  
  # Генерирует слоты для всех сервисных точек на указанную дату
  def self.generate_slots_for_all_service_points(date)
    ServicePoint.active.each do |service_point|
      generate_slots_for_date(service_point.id, date)
    end
  end
  
  # Удаляет все неиспользуемые слоты на указанную дату для указанной сервисной точки
  def self.delete_unused_slots(service_point_id, date)
    # Удаляем только те слоты, которые не связаны с бронированиями
    slots = ScheduleSlot.where(service_point_id: service_point_id, slot_date: date)
                      .left_joins(:bookings)
                      .where(bookings: { id: nil })
    
    slots.destroy_all
  end
  
  private
  
  # Генерирует слоты на основе шаблона расписания
  def self.generate_slots_from_template(service_point, date, template)
    # Сначала удаляем все неиспользуемые слоты для этой даты
    delete_unused_slots(service_point.id, date)
    
    # Определяем время начала и окончания рабочего дня
    start_time = template.start_time
    end_time = template.end_time
    
    # Определяем продолжительность слота
    slot_duration = service_point.default_slot_duration
    
    # Генерируем слоты с шагом, равным продолжительности слота
    current_time = start_time
    while current_time + slot_duration.minutes <= end_time
      slot_end_time = current_time + slot_duration.minutes
      
      # Для каждого поста создаем отдельный слот
      1.upto(service_point.post_count) do |post_number|
        # Проверяем, нет ли уже такого слота
        slot = ScheduleSlot.find_by(
          service_point_id: service_point.id,
          slot_date: date,
          start_time: current_time,
          end_time: slot_end_time,
          post_number: post_number
        )
        
        # Если слота нет, создаем его
        unless slot
          ScheduleSlot.create!(
            service_point_id: service_point.id,
            slot_date: date,
            start_time: current_time,
            end_time: slot_end_time,
            post_number: post_number,
            is_available: true
          )
        end
      end
      
      # Переходим к следующему временному слоту
      current_time = slot_end_time
    end
  end
  
  # Генерирует слоты на основе исключения из расписания
  def self.generate_slots_from_exception(service_point, date, exception)
    # Сначала удаляем все неиспользуемые слоты для этой даты
    delete_unused_slots(service_point.id, date)
    
    # Определяем время начала и окончания рабочего дня
    start_time = exception.start_time
    end_time = exception.end_time
    
    # Определяем продолжительность слота
    slot_duration = service_point.default_slot_duration
    
    # Генерируем слоты с шагом, равным продолжительности слота
    current_time = start_time
    while current_time + slot_duration.minutes <= end_time
      slot_end_time = current_time + slot_duration.minutes
      
      # Для каждого поста создаем отдельный слот
      1.upto(service_point.post_count) do |post_number|
        # Проверяем, нет ли уже такого слота
        slot = ScheduleSlot.find_by(
          service_point_id: service_point.id,
          slot_date: date,
          start_time: current_time,
          end_time: slot_end_time,
          post_number: post_number
        )
        
        # Если слота нет, создаем его
        unless slot
          ScheduleSlot.create!(
            service_point_id: service_point.id,
            slot_date: date,
            start_time: current_time,
            end_time: slot_end_time,
            post_number: post_number,
            is_available: true
          )
        end
      end
      
      # Переходим к следующему временному слоту
      current_time = slot_end_time
    end
  end
  
  # Проверяет, доступен ли указанный временной интервал для бронирования
  def self.is_time_available?(service_point_id, date, start_time, end_time)
    # Проверяем, есть ли свободный слот в указанное время
    slot = ScheduleSlot.where(
      service_point_id: service_point_id,
      slot_date: date,
      start_time: start_time,
      end_time: end_time,
      is_available: true
    ).left_joins(:bookings).where(bookings: { id: nil }).first
    
    return !slot.nil?
  end
  
  # Находит ближайшее свободное время для бронирования
  def self.find_next_available_slot(service_point_id, date, preferred_time = nil)
    service_point = ServicePoint.find(service_point_id)
    
    # Если предпочтительное время не указано, берем текущее время или начало дня
    preferred_time ||= Time.current.strftime("%H:%M:%S")
    
    # Ищем свободный слот на указанную дату
    slot = ScheduleSlot.where(
      service_point_id: service_point_id,
      slot_date: date,
      is_available: true
    ).where("start_time >= ?", preferred_time)
    .left_joins(:bookings)
    .where(bookings: { id: nil })
    .order(start_time: :asc)
    .first
    
    # Если нашли слот на указанную дату, возвращаем его
    return slot if slot
    
    # Если на указанную дату нет свободных слотов, ищем на следующие даты
    next_date = date + 1.day
    next_date_limit = date + 30.days # ограничиваем поиск 30 днями вперед
    
    while next_date <= next_date_limit
      # Генерируем слоты для следующей даты, если их еще нет
      generate_slots_for_date(service_point_id, next_date)
      
      # Ищем свободный слот на следующую дату
      slot = ScheduleSlot.where(
        service_point_id: service_point_id,
        slot_date: next_date,
        is_available: true
      ).left_joins(:bookings)
      .where(bookings: { id: nil })
      .order(start_time: :asc)
      .first
      
      # Если нашли слот, возвращаем его
      return slot if slot
      
      # Переходим к следующей дате
      next_date += 1.day
    end
    
    # Если не нашли свободных слотов, возвращаем nil
    nil
  end
end 