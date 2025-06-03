module Api
  module V1
    class ScheduleController < ApiController
      skip_before_action :authenticate_request, only: [:day, :period]
      before_action :set_service_point
      
      # GET /api/v1/service_points/:id/schedule?date=YYYY-MM-DD
      def day
        date = if params[:date].present?
                 Date.parse(params[:date]) rescue Date.current
               else
                 Date.current
               end
        
        # Получаем день недели (1=Monday, 7=Sunday)
        weekday_number = date.wday == 0 ? 7 : date.wday
        weekday = Weekday.find_by(sort_order: weekday_number)
        
        unless weekday
          render json: { error: "Weekday not found" }, status: :not_found
          return
        end
        
        # Получаем шаблон расписания
        template = @service_point.schedule_templates.find_by(weekday: weekday)
        
        # Проверяем исключения в расписании
        exception = @service_point.schedule_exceptions.find_by(exception_date: date)
        
        # Определяем рабочий ли день
        if exception
          is_working = !exception.is_closed
          start_time = exception.opening_time
          end_time = exception.closing_time
        elsif template
          is_working = template.is_working_day
          start_time = template.opening_time
          end_time = template.closing_time
        else
          is_working = false
          start_time = nil
          end_time = nil
        end
        
        if !is_working || !start_time || !end_time
          render json: {
            service_point_id: @service_point.id,
            date: date.strftime('%Y-%m-%d'),
            is_working_day: false,
            slots: []
          }
          return
        end
        
        # Генерируем доступные временные слоты динамически
        slots = generate_available_slots(date, start_time, end_time)
        
        render json: {
          service_point_id: @service_point.id,
          date: date.strftime('%Y-%m-%d'),
          is_working_day: true,
          working_hours: {
            start: start_time.strftime('%H:%M'),
            end: end_time.strftime('%H:%M')
          },
          slots: slots
        }
      end
      
      # GET /api/v1/schedule/:service_point_id/:from_date/:to_date
      def period
        from_date = Date.parse(params[:from_date]) rescue Date.current
        to_date = Date.parse(params[:to_date]) rescue (Date.current + 1.month)
        
        # Ограничиваем период
        max_days = 31
        to_date = from_date + max_days.days if (to_date - from_date).to_i > max_days
        
        days_schedule = []
        
        (from_date..to_date).each do |date|
          weekday_number = date.wday == 0 ? 7 : date.wday
          weekday = Weekday.find_by(sort_order: weekday_number)
          
          next unless weekday
          
          template = @service_point.schedule_templates.find_by(weekday: weekday)
          exception = @service_point.schedule_exceptions.find_by(exception_date: date)
          
          if exception
            is_working = !exception.is_closed
            start_time = exception.opening_time
            end_time = exception.closing_time
          elsif template
            is_working = template.is_working_day
            start_time = template.opening_time
            end_time = template.closing_time
          else
            is_working = false
          end
          
          if is_working && start_time && end_time
            available_slots = generate_available_slots(date, start_time, end_time)
            available_count = available_slots.count { |slot| slot[:is_available] }
          else
            available_count = 0
          end
          
          days_schedule << {
            date: date.strftime('%Y-%m-%d'),
            weekday: weekday.name,
            is_working_day: is_working,
            working_hours: is_working ? {
              start: start_time&.strftime('%H:%M'),
              end: end_time&.strftime('%H:%M')
            } : nil,
            available_slots_count: available_count,
            is_fully_booked: available_count == 0
          }
        end
        
        render json: {
          service_point_id: @service_point.id,
          from_date: from_date.strftime('%Y-%m-%d'),
          to_date: to_date.strftime('%Y-%m-%d'),
          days: days_schedule
        }
      end
      
      private
      
      def set_service_point
        @service_point = ServicePoint.find(params[:service_point_id] || params[:id])
      end
      
      # Генерирует доступные временные слоты динамически
      def generate_available_slots(date, start_time, end_time)
        slots = []
        slot_duration = @service_point.default_slot_duration || 60 # минуты
        
        # Получаем существующие бронирования на эту дату
        existing_bookings = @service_point.bookings
                                         .where(booking_date: date)
                                         .where.not(status: ['cancelled', 'no_show'])
        
        current_time = start_time
        slot_id = 1
        
        while current_time + slot_duration.minutes <= end_time
          slot_end_time = current_time + slot_duration.minutes
          
          # Проверяем, есть ли бронирование в это время
          is_booked = existing_bookings.any? do |booking|
            booking_start = Time.zone.parse("#{date} #{booking.start_time}")
            booking_end = Time.zone.parse("#{date} #{booking.end_time}")
            current_slot_start = Time.zone.parse("#{date} #{current_time}")
            current_slot_end = Time.zone.parse("#{date} #{slot_end_time}")
            
            # Проверяем пересечение времени
            (current_slot_start < booking_end) && (current_slot_end > booking_start)
          end
          
          slots << {
            id: slot_id,
            start_time: current_time.strftime('%H:%M'),
            end_time: slot_end_time.strftime('%H:%M'),
            duration_minutes: slot_duration,
            is_available: !is_booked,
            is_booked: is_booked
          }
          
          current_time = slot_end_time
          slot_id += 1
        end
        
        slots
      end
    end
  end
end
