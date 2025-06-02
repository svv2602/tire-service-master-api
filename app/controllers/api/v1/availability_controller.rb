# app/controllers/api/v1/availability_controller.rb
# Контроллер для работы с динамической доступностью

class Api::V1::AvailabilityController < ApplicationController
  skip_before_action :authenticate_request
  before_action :set_service_point
  
  # GET /api/v1/service_points/:service_point_id/availability/:date
  # Получение доступных временных интервалов на дату
  def available_times
    date = parse_date(params[:date])
    min_duration = params[:min_duration_minutes]&.to_i
    
    available_times = DynamicAvailabilityService.available_times_for_date(
      @service_point.id, 
      date, 
      min_duration
    )
    
    render json: {
      service_point_id: @service_point.id,
      date: date.strftime('%Y-%m-%d'),
      min_duration_minutes: min_duration,
      available_times: available_times,
      total_intervals: available_times.count
    }
  end
  
  # POST /api/v1/service_points/:service_point_id/availability/check
  # Проверка доступности конкретного времени
  def check_time
    date = parse_date(params[:date])
    time_str = params[:time] # "14:30"
    duration_minutes = params[:duration_minutes]&.to_i || 60
    
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
    after_time_str = params[:after_time] # "14:30" или nil
    duration_minutes = params[:duration_minutes]&.to_i || 60
    
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
        next_available: next_slot
      }
    else
      render json: {
        service_point_id: @service_point.id,
        requested_date: date.strftime('%Y-%m-%d'),
        requested_after_time: after_time_str,
        duration_minutes: duration_minutes,
        found: false,
        message: 'Свободное время не найдено в ближайшие 30 дней'
      }
    end
  end
  
  # GET /api/v1/service_points/:service_point_id/availability/:date/details
  # Детальная информация о загрузке на день
  def day_details
    date = parse_date(params[:date])
    
    details = DynamicAvailabilityService.day_occupancy_details(@service_point.id, date)
    
    render json: {
      service_point_id: @service_point.id,
      service_point_name: @service_point.name,
      date: date.strftime('%Y-%m-%d'),
      **details
    }
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
    render json: { error: 'Неверный формат даты' }, status: :bad_request
    nil
  end
end 