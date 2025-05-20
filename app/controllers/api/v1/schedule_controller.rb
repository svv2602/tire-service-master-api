module Api
  module V1
    class ScheduleController < ApiController
      skip_before_action :authenticate_request, only: [:day, :period]
      before_action :set_service_point
      before_action :authorize_admin_or_partner, only: [:generate_for_date, :generate_for_period]
      
      # GET /api/v1/schedule/:service_point_id/:date
      def day
        date = Date.parse(params[:date]) rescue Date.current
        
        # Используем метод из ServicePoint
        slots = @service_point.available_slots_for_date(date).map do |slot|
          {
            id: slot.id,
            date: slot.slot_date.strftime('%Y-%m-%d'),
            start_time: slot.start_time.strftime('%H:%M'),
            end_time: slot.end_time.strftime('%H:%M'),
            duration_minutes: slot.duration_in_minutes,
            post_number: slot.post_number,
            is_available: slot.is_available && !slot.booked?
          }
        end
        
        render json: {
          service_point_id: @service_point.id,
          date: date,
          slots: slots
        }
      end
      
      # GET /api/v1/schedule/:service_point_id/:from_date/:to_date
      def period
        from_date = Date.parse(params[:from_date]) rescue Date.current
        to_date = Date.parse(params[:to_date]) rescue (Date.current + 1.month)
        
        # Ограничиваем период для API
        max_days = 31
        to_date = from_date + max_days.days if (to_date - from_date).to_i > max_days
        
        days_schedule = []
        
        # Для каждого дня в диапазоне получаем расписание
        (from_date..to_date).each do |date|
          # Используем метод generate_schedule_for_date, чтобы убедиться, что слоты созданы
          @service_point.generate_schedule_for_date(date)
          
          # Получаем информацию о дне недели
          weekday = Weekday.find_by(day_number: date.wday)
          
          # Получаем шаблон расписания на этот день недели
          template = @service_point.schedule_templates.find_by(weekday_id: weekday.id)
          
          # Проверяем, нет ли исключения в расписании на эту дату
          exception = @service_point.schedule_exceptions.find_by(exception_date: date)
          
          # Определяем, является ли день рабочим
          is_working_day = if exception
                           exception.is_working_day
                         elsif template
                           template.is_working_day
                         else
                           false
                         end
          
          # Если день рабочий, получаем информацию о слотах
          if is_working_day
            # Получаем доступные слоты
            available_slots = @service_point.available_slots_for_date(date)
            
            # Определяем время работы
            start_time = if exception && exception.is_working_day
                         exception.start_time
                       elsif template
                         template.start_time
                       else
                         nil
                       end
            
            end_time = if exception && exception.is_working_day
                       exception.end_time
                     elsif template
                       template.end_time
                     else
                       nil
                     end
            
            # Добавляем информацию о дне в результат
            days_schedule << {
              date: date.strftime('%Y-%m-%d'),
              weekday: weekday.name,
              is_working_day: true,
              working_hours: {
                start: start_time&.strftime('%H:%M'),
                end: end_time&.strftime('%H:%M')
              },
              available_slots_count: available_slots.count,
              is_fully_booked: available_slots.empty?
            }
          else
            # День нерабочий
            days_schedule << {
              date: date.strftime('%Y-%m-%d'),
              weekday: weekday.name,
              is_working_day: false,
              available_slots_count: 0,
              is_fully_booked: true
            }
          end
        end
        
        render json: {
          service_point_id: @service_point.id,
          from_date: from_date.strftime('%Y-%m-%d'),
          to_date: to_date.strftime('%Y-%m-%d'),
          days: days_schedule
        }
      end
      
      # POST /api/v1/schedule/generate_for_date/:service_point_id/:date
      def generate_for_date
        date = Date.parse(params[:date]) rescue Date.current
        
        # Генерируем слоты используя метод из ServicePoint
        @service_point.generate_schedule_for_date(date)
        
        # Получаем созданные слоты
        slots = @service_point.schedule_slots.where(slot_date: date).order(start_time: :asc).map do |slot|
          {
            id: slot.id,
            date: slot.slot_date.strftime('%Y-%m-%d'),
            start_time: slot.start_time.strftime('%H:%M'),
            end_time: slot.end_time.strftime('%H:%M'),
            duration_minutes: slot.duration_in_minutes,
            post_number: slot.post_number,
            is_available: slot.is_available && !slot.booked?
          }
        end
        
        render json: {
          message: "Schedule generated successfully",
          service_point_id: @service_point.id,
          date: date.strftime('%Y-%m-%d'),
          slots_count: slots.count,
          slots: slots
        }
      end
      
      # POST /api/v1/schedule/generate_for_period/:service_point_id/:from_date/:to_date
      def generate_for_period
        from_date = Date.parse(params[:from_date]) rescue Date.current
        to_date = Date.parse(params[:to_date]) rescue (Date.current + 1.month)
        
        # Ограничиваем период для API
        max_days = 31
        to_date = from_date + max_days.days if (to_date - from_date).to_i > max_days
        
        # Генерируем слоты используя метод из ServicePoint
        @service_point.generate_schedule_for_period(from_date, to_date)
        
        render json: {
          message: "Schedule generated successfully",
          service_point_id: @service_point.id,
          from_date: from_date.strftime('%Y-%m-%d'),
          to_date: to_date.strftime('%Y-%m-%d'),
          days_count: (to_date - from_date).to_i + 1
        }
      end
      
      private
      
      def set_service_point
        @service_point = ServicePoint.find(params[:service_point_id])
      end
      
      def authorize_admin_or_partner
        unless current_user && (current_user.admin? || 
                (current_user.role.name == 'operator' && @service_point.partner.user_id == current_user.id))
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end
