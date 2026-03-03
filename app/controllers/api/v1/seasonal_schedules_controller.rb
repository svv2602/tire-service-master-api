module Api
  module V1
    class SeasonalSchedulesController < ApiController
      skip_after_action :verify_authorized
      before_action :set_service_point
      before_action :set_seasonal_schedule, only: [:show, :update, :destroy]
      
      # GET /api/v1/service_points/:service_point_id/seasonal_schedules
      def index
        @seasonal_schedules = @service_point.seasonal_schedules
                                           .includes(:service_point)
                                           .by_priority
        
        # Фильтрация по статусу
        if params[:status].present?
          case params[:status]
          when 'active'
            @seasonal_schedules = @seasonal_schedules.active
          when 'inactive'
            @seasonal_schedules = @seasonal_schedules.inactive
          when 'current'
            @seasonal_schedules = @seasonal_schedules.current
          when 'upcoming'
            @seasonal_schedules = @seasonal_schedules.upcoming
          when 'past'
            @seasonal_schedules = @seasonal_schedules.past
          end
        end
        
        # Фильтрация по дате
        if params[:date].present?
          date = Date.parse(params[:date]) rescue nil
          if date
            @seasonal_schedules = @seasonal_schedules.where('start_date <= ? AND end_date >= ?', date, date)
          end
        end
        
        # Используем метод paginate из базового контроллера
        result = paginate(@seasonal_schedules)
        
        render json: {
          data: result[:data].map { |schedule| serialize_seasonal_schedule(schedule) },
          pagination: result[:pagination]
        }
      end
      
      # GET /api/v1/service_points/:service_point_id/seasonal_schedules/:id
      def show
        render json: { data: serialize_seasonal_schedule(@seasonal_schedule) }
      end
      
      # POST /api/v1/service_points/:service_point_id/seasonal_schedules
      def create
        @seasonal_schedule = @service_point.seasonal_schedules.build(seasonal_schedule_params)
        
        if @seasonal_schedule.save
          render json: { 
            data: serialize_seasonal_schedule(@seasonal_schedule),
            message: 'Сезонное расписание успешно создано'
          }, status: :created
        else
          render json: { 
            errors: @seasonal_schedule.errors.full_messages 
          }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/service_points/:service_point_id/seasonal_schedules/:id
      def update
        if @seasonal_schedule.update(seasonal_schedule_params)
          render json: { 
            data: serialize_seasonal_schedule(@seasonal_schedule),
            message: 'Сезонное расписание успешно обновлено'
          }
        else
          render json: { 
            errors: @seasonal_schedule.errors.full_messages 
          }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/service_points/:service_point_id/seasonal_schedules/:id
      def destroy
        @seasonal_schedule.destroy
        render json: { message: 'Сезонное расписание успешно удалено' }
      end
      
      # GET /api/v1/service_points/:service_point_id/seasonal_schedules/active_for_date
      def active_for_date
        date = Date.parse(params[:date]) rescue Date.current
        
        seasonal_schedule = SeasonalSchedule.find_active_for_date(@service_point.id, date)
        
        if seasonal_schedule
          render json: { 
            data: serialize_seasonal_schedule(seasonal_schedule),
            message: 'Найдено активное сезонное расписание'
          }
        else
          render json: { 
            data: nil,
            message: 'Активное сезонное расписание не найдено'
          }
        end
      end
      
      # GET /api/v1/service_points/:service_point_id/seasonal_schedules/active_for_period
      def active_for_period
        start_date = Date.parse(params[:start_date]) rescue Date.current
        end_date = Date.parse(params[:end_date]) rescue Date.current
        
        seasonal_schedules = SeasonalSchedule.find_active_for_period(@service_point.id, start_date, end_date)
        
        render json: {
          data: seasonal_schedules.map { |schedule| serialize_seasonal_schedule(schedule) },
          period: {
            start_date: start_date.strftime('%Y-%m-%d'),
            end_date: end_date.strftime('%Y-%m-%d')
          }
        }
      end
      
      private
      
      def set_service_point
        @service_point = ServicePoint.find(params[:service_point_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Сервисная точка не найдена' }, status: :not_found
      end
      
      def set_seasonal_schedule
        @seasonal_schedule = @service_point.seasonal_schedules.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Сезонное расписание не найдено' }, status: :not_found
      end
      
      def seasonal_schedule_params
        params.require(:seasonal_schedule).permit(
          :name,
          :description,
          :start_date,
          :end_date,
          :is_active,
          :priority,
          working_hours: [
            :monday => [:is_working_day, :start, :end],
            :tuesday => [:is_working_day, :start, :end],
            :wednesday => [:is_working_day, :start, :end],
            :thursday => [:is_working_day, :start, :end],
            :friday => [:is_working_day, :start, :end],
            :saturday => [:is_working_day, :start, :end],
            :sunday => [:is_working_day, :start, :end]
          ]
        )
      end
      
      def serialize_seasonal_schedule(schedule)
        {
          id: schedule.id,
          service_point_id: schedule.service_point_id,
          name: schedule.name,
          description: schedule.description,
          start_date: schedule.start_date.strftime('%Y-%m-%d'),
          end_date: schedule.end_date.strftime('%Y-%m-%d'),
          period_description: schedule.period_description,
          working_hours: schedule.working_hours,
          is_active: schedule.is_active,
          priority: schedule.priority,
          working_days_count: schedule.working_days_count,
          status: determine_schedule_status(schedule),
          created_at: schedule.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          updated_at: schedule.updated_at.strftime('%Y-%m-%d %H:%M:%S')
        }
      end
      
      def determine_schedule_status(schedule)
        return 'inactive' unless schedule.is_active
        
        current_date = Date.current
        
        if schedule.start_date > current_date
          'upcoming'
        elsif schedule.end_date < current_date
          'past'
        else
          'current'
        end
      end
    end
  end
end 