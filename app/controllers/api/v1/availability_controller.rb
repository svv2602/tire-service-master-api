# app/controllers/api/v1/availability_controller.rb
# Контроллер для работы с динамической доступностью

class Api::V1::AvailabilityController < ApplicationController
  skip_before_action :authenticate_request
  before_action :set_service_point
  
  # GET /api/v1/service_points/:service_point_id/availability/:date
  # Получение доступных временных интервалов на дату
  def available_times
    date = parse_date(params[:date])
    return if date.nil? # Если parse_date уже отрендерил ошибку, выходим
    
    min_duration = params[:min_duration_minutes]&.to_i || params[:duration]&.to_i
    
    begin
      available_times = DynamicAvailabilityService.available_times_for_date(
        @service_point.id, 
        date, 
        min_duration
      )
      
      # Проверяем рабочий ли день
      schedule_info = DynamicAvailabilityService.send(:get_schedule_for_date, @service_point, date)
      
      render json: {
        service_point_id: @service_point.id,
        date: date.strftime('%Y-%m-%d'),
        duration: min_duration,
        min_duration_minutes: min_duration,
        is_working_day: schedule_info[:is_working],
        available_times: available_times,
        total_intervals: available_times.count
      }
    rescue => e
      render json: { error: "Внутренняя ошибка сервера: #{e.message}" }, status: :internal_server_error
    end
  end
  
  # POST /api/v1/service_points/:service_point_id/availability/check
  # Проверка доступности конкретного времени
  def check_time
    date = parse_date(params[:date])
    return if date.nil? # Если parse_date уже отрендерил ошибку, выходим
    
    time_str = params[:time] # "14:30"
    duration_minutes = params[:duration_minutes]&.to_i || 60
    
    # Проверяем наличие обязательных параметров
    if time_str.blank?
      return render json: { error: 'Параметр time обязателен' }, status: :bad_request
    end
    
    begin
      time = Time.parse("#{date} #{time_str}")
    rescue ArgumentError
      return render json: { error: 'Неверный формат времени' }, status: :bad_request
    end
    
    availability = DynamicAvailabilityService.check_availability_at_time(
      @service_point.id,
      date,
      time,
      duration_minutes
    )
    
    render json: {
      service_point_id: @service_point.id,
      date: date.strftime('%Y-%m-%d'),
      time: time_str,
      duration_minutes: duration_minutes,
      **availability
    }
  end
  
  # GET /api/v1/service_points/:service_point_id/availability/:date/next
  # Поиск ближайшего доступного времени
  def next_available
    date = parse_date(params[:date])
    return if date.nil? # Если parse_date уже отрендерил ошибку, выходим
    
    after_time_str = params[:after_time] # "14:30" или nil
    duration_minutes = params[:duration_minutes]&.to_i || params[:duration]&.to_i || 60
    
    after_time = if after_time_str
                   begin
                     Time.parse("#{date} #{after_time_str}")
                   rescue ArgumentError
                     return render json: { error: 'Неверный формат времени' }, status: :bad_request
                   end
                 else
                   Time.current
                 end
    
    next_slot = DynamicAvailabilityService.find_next_available_time(
      @service_point.id,
      date,
      after_time,
      duration_minutes
    )
    
    if next_slot
      render json: {
        service_point_id: @service_point.id,
        requested_date: date.strftime('%Y-%m-%d'),
        requested_after_time: after_time_str,
        duration_minutes: duration_minutes,
        found: true,
        next_available_time: next_slot
      }
    else
      render json: {
        service_point_id: @service_point.id,
        requested_date: date.strftime('%Y-%m-%d'),
        requested_after_time: after_time_str,
        duration_minutes: duration_minutes,
        found: false,
        next_available_time: nil,
        message: 'Нет доступных времён в ближайшие 30 дней'
      }
    end
  end
  
  # GET /api/v1/service_points/:service_point_id/availability/:date/details
  # Детальная информация о загрузке на день
  def day_details
    date = parse_date(params[:date])
    return if date.nil? # Если parse_date уже отрендерил ошибку, выходим
    
    begin
      details = DynamicAvailabilityService.day_occupancy_details(@service_point.id, date)
      
      render json: {
        service_point_id: @service_point.id,
        service_point_name: @service_point.name,
        date: date.strftime('%Y-%m-%d'),
        **details
      }
    rescue => e
      render json: { error: "Внутренняя ошибка сервера: #{e.message}" }, status: :internal_server_error
    end
  end
  
  # GET /api/v1/service_points/:service_point_id/availability/week
  # Обзор доступности на неделю
  def week_overview
    start_date = parse_date(params[:start_date]) || Date.current
    end_date = start_date + 6.days
    
    week_data = []
    
    (start_date..end_date).each do |date|
      day_summary = DynamicAvailabilityService.day_occupancy_details(@service_point.id, date)
      
      week_data << {
        date: date.strftime('%Y-%m-%d'),
        weekday: date.strftime('%A'),
        is_working: day_summary[:is_working],
        total_posts: day_summary[:total_posts],
        summary: day_summary[:summary] || {}
      }
    end
    
    render json: {
      service_point_id: @service_point.id,
      service_point_name: @service_point.name,
      week_start: start_date.strftime('%Y-%m-%d'),
      week_end: end_date.strftime('%Y-%m-%d'),
      days: week_data
    }
  end
  
  private
  
  def set_service_point
    @service_point = ServicePoint.find(params[:id] || params[:service_point_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Точка обслуживания не найдена' }, status: :not_found
  end
  
  def parse_date(date_string)
    Date.parse(date_string)
  rescue ArgumentError, TypeError
    render json: { error: 'Некорректный формат даты' }, status: :bad_request
    nil
  end
end 