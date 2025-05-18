module Api
  module V1
    class ScheduleController < ApiController
      skip_before_action :authenticate_request, only: [:day, :period]
      
      # GET /api/v1/schedule/:service_point_id/:date
      def day
        @service_point = ServicePoint.find(params[:service_point_id])
        date = Date.parse(params[:date]) rescue Date.current
        
        # Получаем доступные слоты на выбранную дату
        slots = get_available_slots(@service_point, date)
        
        render json: {
          service_point_id: @service_point.id,
          date: date,
          slots: slots
        }
      end
      
      # GET /api/v1/schedule/:service_point_id/:from_date/:to_date
      def period
        @service_point = ServicePoint.find(params[:service_point_id])
        
        from_date = Date.parse(params[:from_date]) rescue Date.current
        to_date = Date.parse(params[:to_date]) rescue (Date.current + 1.month)
        
        # Ограничиваем период для API
        max_days = 31
        to_date = from_date + max_days.days if (to_date - from_date).to_i > max_days
        
        days_schedule = []
        
        # Для каждого дня в диапазоне получаем расписание
        (from_date..to_date).each do |date|
          # Получаем шаблон расписания на этот день недели
          template = @service_point.schedule_templates.find_by(weekday: date.wday)
          
          # Если шаблон существует и день рабочий
          if template && template.is_working_day
            # Проверяем нет ли исключения в расписании на эту дату
            exception = @service_point.schedule_exceptions.find_by(exception_date: date)
            
            # Если есть исключение и это выходной, пропускаем
            next if exception && !exception.is_working_day
            
            # Получаем доступные слоты
            slots = get_available_slots(@service_point, date)
            
            # Добавляем информацию о дне в результат
            days_schedule << {
              date: date,
              weekday: date.strftime('%A'),
              is_working_day: true,
              working_hours: {
                open: template.open_time,
                close: template.close_time
              },
              available_slots_count: slots.count,
              is_fully_booked: slots.empty?
            }
          else
            # День нерабочий
            days_schedule << {
              date: date,
              weekday: date.strftime('%A'),
              is_working_day: false,
              available_slots_count: 0,
              is_fully_booked: true
            }
          end
        end
        
        render json: {
          service_point_id: @service_point.id,
          from_date: from_date,
          to_date: to_date,
          days: days_schedule
        }
      end
      
      private
      
      def get_available_slots(service_point, date)
        # Получаем шаблон расписания для дня недели
        weekday = date.wday
        template = service_point.schedule_templates.find_by(weekday: weekday)
        
        # Если нет шаблона или день нерабочий, возвращаем пустой массив
        return [] if template.nil? || !template.is_working_day
        
        # Проверяем, нет ли исключения на эту дату
        exception = service_point.schedule_exceptions.find_by(exception_date: date)
        
        # Если есть исключение и день нерабочий, возвращаем пустой массив
        return [] if exception && !exception.is_working_day
        
        # Определяем время начала и окончания работы
        open_time = exception&.open_time || template.open_time
        close_time = exception&.close_time || template.close_time
        
        # Получаем существующие слоты
        existing_slots = service_point.schedule_slots
                               .where(date: date)
                               .order(start_time: :asc)
        
        # Если слоты уже созданы в системе, возвращаем свободные
        unless existing_slots.empty?
          return existing_slots.where(status: 'available').map do |slot|
            {
              id: slot.id,
              start_time: slot.start_time.strftime('%H:%M'),
              end_time: slot.end_time.strftime('%H:%M'),
              duration_minutes: ((slot.end_time - slot.start_time) / 60).to_i,
              status: slot.status
            }
          end
        end
        
        # Если слотов на эту дату нет в системе, генерируем их на основе шаблона
        duration_minutes = service_point.default_slot_duration
        post_count = service_point.post_count
        
        # Преобразуем строки времени в объекты Time
        day_start = Time.zone.parse("#{date} #{open_time}")
        day_end = Time.zone.parse("#{date} #{close_time}")
        
        slots = []
        current_time = day_start
        
        # Генерируем слоты с фиксированной длительностью
        while current_time + duration_minutes.minutes <= day_end
          slot_end = current_time + duration_minutes.minutes
          
          # Для каждого поста создаем отдельный слот
          post_count.times do |post_number|
            slots << {
              # Присваиваем id только существующим слотам
              start_time: current_time.strftime('%H:%M'),
              end_time: slot_end.strftime('%H:%M'),
              duration_minutes: duration_minutes,
              status: 'available',
              post_number: post_number + 1
            }
          end
          
          # Переходим к следующему временному слоту
          current_time = slot_end
        end
        
        # Фильтруем прошедшие слоты для текущего дня
        if date == Date.current
          current_time = Time.current
          slots.reject! { |slot| Time.zone.parse("#{date} #{slot[:end_time]}") < current_time }
        end
        
        slots
      end
    end
  end
end
