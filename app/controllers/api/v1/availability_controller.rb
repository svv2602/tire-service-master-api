# app/controllers/api/v1/availability_controller.rb
# Контроллер для работы с динамической доступностью

class Api::V1::AvailabilityController < ApplicationController
  skip_before_action :authenticate_request, except: [:client_check_availability]
  before_action :set_service_point, except: [:client_check_availability, :check_with_category, :slots_for_category]
  
  # GET /api/v1/availability/:service_point_id/:date  
  # Получение доступных временных слотов для клиентов (упрощенная версия)
  def client_available_times
    date = parse_date(params[:date])
    return if date.nil? # Если parse_date уже отрендерил ошибку, выходим
    
    # Фильтруем прошедшее время для сегодняшней даты
    current_time = Time.current
    
    begin
      # Получаем информацию о расписании (включая сезонные)
      schedule_info = DynamicAvailabilityService.send(:get_schedule_for_date, @service_point, date)
      
      available_times = DynamicAvailabilityService.available_times_for_date(
        @service_point.id, 
        date
      )
      
      # Убираем прошедшие слоты для сегодняшней даты
      if date == Date.current
        available_times = available_times.select do |slot|
          slot[:datetime] > current_time
        end
      end
      
      # Проверяем рабочий ли день (новая логика с индивидуальными постами)
      is_working_day = DynamicAvailabilityService.has_any_working_posts_on_date?(@service_point, date)
      
      render json: {
        service_point_id: @service_point.id,
        service_point_name: @service_point.name,
        date: date.strftime('%Y-%m-%d'),
        is_working_day: is_working_day,
        available_slots: available_times.map do |slot|
          {
            time: slot[:time],
            available_posts: slot[:available_posts],
            total_posts: slot[:total_posts],
            status: slot[:available_posts] > 2 ? 'available' : 
                   slot[:available_posts] > 0 ? 'limited' : 'full'
          }
        end,
        total_slots: available_times.count,
        schedule_info: {
          is_working: schedule_info[:is_working],
          schedule_type: schedule_info[:schedule_type],
          schedule_name: schedule_info[:schedule_name],
          opening_time: schedule_info[:opening_time]&.strftime('%H:%M'),
          closing_time: schedule_info[:closing_time]&.strftime('%H:%M')
        }
      }
    rescue => e
      render json: { error: "Внутренняя ошибка сервера: #{e.message}" }, status: :internal_server_error
    end
  end
  
  # GET /api/v1/service_points/:service_point_id/availability/:date
  # Получение доступных временных интервалов на дату
  def available_times
    date = parse_date(params[:date])
    return if date.nil? # Если parse_date уже отрендерил ошибку, выходим
    
    min_duration = params[:min_duration_minutes]&.to_i || params[:duration]&.to_i
    
    begin
      # Используем обратную совместимость с группировкой по времени
      available_times_data = DynamicAvailabilityService.available_times_for_date(
        @service_point.id, 
        date,
        min_duration
      )
      
      # Фильтруем прошедшее время для сегодняшней даты
      current_time = Time.current
      if date == Date.current
        available_times_data = available_times_data.select do |slot|
          slot[:datetime] > current_time
        end
      end
      
      render json: {
        service_point_id: @service_point.id,
        date: date.strftime('%Y-%m-%d'),
        min_duration_minutes: min_duration,
        available_times: available_times_data.map do |slot|
          {
            time: slot[:time],
            available_posts: slot[:available_posts],
            total_posts: slot[:total_posts],
            can_book: true # Слоты уже отфильтрованы по доступности
          }
        end,
        total_intervals: available_times_data.count
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
  # Получение детальной информации о загрузке дня
  def day_details
    date = parse_date(params[:date])
    return if date.nil? # Если parse_date уже отрендерил ошибку, выходим
    
    category_id = params[:category_id]&.to_i
    
    begin
      if category_id.present?
        # Получаем детали для конкретной категории
        details = DynamicAvailabilityService.day_occupancy_details_for_category(@service_point.id, date, category_id)
      else
        # Получаем общие детали по всем постам
        details = DynamicAvailabilityService.day_occupancy_details(@service_point.id, date)
      end
      
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
  
  # POST /api/v1/bookings/check_availability
  # Быстрая проверка доступности времени перед созданием записи
  def client_check_availability
    date = parse_date(params[:date])
    return if date.nil?
    
    time_str = params[:time] # "14:30" 
    service_point_id = params[:service_point_id]
    
    # Проверяем наличие обязательных параметров
    if service_point_id.blank?
      return render json: { 
        error: 'Параметры date, time и service_point_id обязательны' 
      }, status: :bad_request
    end
    
    if time_str.blank?
      return render json: { 
        error: 'Параметры date, time и service_point_id обязательны' 
      }, status: :bad_request
    end
    
    begin
      service_point = ServicePoint.find(service_point_id)
      time = Time.parse("#{date} #{time_str}")
      
      # Проверяем, что время не в прошлом
      if date == Date.current && time <= Time.current
        return render json: {
          available: false,
          reason: 'Нельзя записаться в прошедшее время'
        }
      end
      
      availability = DynamicAvailabilityService.check_availability_at_time(
        service_point.id,
        date,
        time
      )
      
      render json: {
        service_point_id: service_point.id,
        service_point_name: service_point.name,
        date: date.strftime('%Y-%m-%d'),
        time: time_str,
        **availability
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Сервисная точка не найдена' }, status: :not_found
    rescue ArgumentError
      render json: { error: 'Неверный формат времени' }, status: :bad_request
    rescue => e
      render json: { error: "Внутренняя ошибка сервера: #{e.message}" }, status: :internal_server_error
    end
  end
  
  # POST /api/v1/availability/check_with_category
  def check_with_category
    service_point_id = params[:servicePointId]
    date = params[:date]
    start_time = params[:startTime]
    duration = params[:duration]&.to_i || 60
    category_id = params[:categoryId]
    
    # Валидация параметров
    required_params = [service_point_id, date, start_time, category_id]
    if required_params.any?(&:blank?)
      return render json: { 
        error: 'Не все обязательные параметры переданы' 
      }, status: :bad_request
    end
    
    begin
      result = DynamicAvailabilityService.check_availability_with_category(
        service_point_id, date, start_time, duration, category_id
      )
      
      render json: result
    rescue => e
      render json: { 
        error: "Ошибка проверки доступности: #{e.message}" 
      }, status: :internal_server_error
    end
  end
  
  # GET /api/v1/availability/slots_for_category?service_point_id=1&date=2025-01-01&category_id=1
  def slots_for_category
    begin
      Rails.logger.info "🚀 slots_for_category started"
      
      service_point_id = params[:service_point_id]
      date = params[:date]
      category_id = params[:category_id]
      
      Rails.logger.info "📋 Parameters: service_point_id=#{service_point_id}, date=#{date}, category_id=#{category_id}"
      
      # Валидация параметров
      required_params = [service_point_id, date, category_id]
      if required_params.any?(&:blank?)
        return render json: { 
          error: 'Не все обязательные параметры переданы' 
        }, status: :bad_request
      end

      Rails.logger.info "✅ Parameters validated"
      
      service_point = ServicePoint.find(service_point_id)
      Rails.logger.info "✅ ServicePoint found: #{service_point.name}"
      
      parsed_date = Date.parse(date)
      Rails.logger.info "✅ Date parsed: #{parsed_date}"
      
      # Получаем информацию о расписании (включая сезонные)
      Rails.logger.info "🔄 Getting schedule info..."
      schedule_info = DynamicAvailabilityService.get_schedule_for_date(service_point, parsed_date)
      Rails.logger.info "✅ Schedule info received: #{schedule_info.inspect}"
      
      # Определяем роль пользователя для служебных бронирований
      # Пробуем получить пользователя опционально (без требования авторизации)
      Rails.logger.info "🔄 Getting current user..."
      current_user = try_get_current_user
      Rails.logger.info "✅ Current user: #{current_user&.email || 'not authenticated'}"
      
      is_service_user = current_user && current_user.role && ['admin', 'partner', 'manager', 'operator'].include?(current_user.role.name)
      Rails.logger.info "✅ Is service user: #{is_service_user}"
      
      # Получаем слоты в зависимости от роли пользователя
      if is_service_user
        # Для служебных ролей возвращаем ВСЕ слоты с информацией о загруженности
        Rails.logger.info "  🔧 Используем all_slots_for_category_with_occupancy"
        slots = DynamicAvailabilityService.all_slots_for_category_with_occupancy(
          service_point.id, parsed_date, category_id
        )
      else
        # Для обычных клиентов возвращаем только доступные слоты
        Rails.logger.info "  👤 Используем available_slots_for_category"
        slots = DynamicAvailabilityService.available_slots_for_category(
          service_point.id, parsed_date, category_id
        )
      end
      
      Rails.logger.info "  📊 Получено слотов: #{slots.count}"
      Rails.logger.info "  🕘 Времена слотов: #{slots.map { |s| s[:start_time] }.join(', ')}"
      slot_945 = slots.find { |s| s[:start_time] == '09:45' }
      if slot_945
        Rails.logger.info "  🎯 Слот 9:45 найден: #{slot_945}"
      else
        Rails.logger.info "  ❌ Слот 9:45 НЕ найден"
      end
      
      # Получаем общее количество постов для категории
      total_posts_count = service_point.posts_count_for_category(category_id.to_i)
      
      render json: {
        service_point_id: service_point_id,
        date: date,
        category_id: category_id,
        slots: slots,
        total_slots: slots.count,
        total_posts_count: total_posts_count,
        is_service_user: is_service_user, # Добавляем информацию о типе пользователя
        schedule_info: {
          is_working: schedule_info[:is_working],
          schedule_type: schedule_info[:schedule_type],
          schedule_name: schedule_info[:schedule_name],
          opening_time: schedule_info[:opening_time]&.strftime('%H:%M'),
          closing_time: schedule_info[:closing_time]&.strftime('%H:%M')
        }
      }
    rescue => e
      render json: { 
        error: "Ошибка получения слотов: #{e.message}" 
      }, status: :internal_server_error
    end
  end
  
  # GET /api/v1/service_points/:service_point_id/availability/month_load
  # Получение загрузки на месяц для цветовой индикации в календаре
  def month_load
    start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    end_date = params[:end_date]&.to_date || start_date.end_of_month
    category_id = params[:category_id]&.to_i

    days_data = []

    (start_date..end_date).each do |date|
      begin
        day_info = if category_id.present?
                     DynamicAvailabilityService.day_occupancy_details_for_category(@service_point.id, date, category_id)
                   else
                     DynamicAvailabilityService.day_occupancy_details(@service_point.id, date)
                   end

        # Calculate load percentage and color indicator
        occupancy_percent = day_info[:summary][:occupancy_percent] || 0
        load_indicator = calculate_load_indicator(occupancy_percent, day_info[:is_working])

        days_data << {
          date: date.strftime('%Y-%m-%d'),
          weekday: date.wday,
          is_working: day_info[:is_working],
          occupancy_percent: occupancy_percent,
          available_slots: day_info[:summary][:available_slots] || 0,
          total_slots: day_info[:summary][:total_slots] || 0,
          booked_slots: day_info[:summary][:booked_slots] || 0,
          load_indicator: load_indicator
        }
      rescue StandardError => e
        Rails.logger.error "Error getting day occupancy for #{date}: #{e.message}"
        days_data << {
          date: date.strftime('%Y-%m-%d'),
          weekday: date.wday,
          is_working: false,
          occupancy_percent: 0,
          available_slots: 0,
          total_slots: 0,
          booked_slots: 0,
          load_indicator: 'unavailable'
        }
      end
    end

    render json: {
      service_point_id: @service_point.id,
      service_point_name: @service_point.name,
      start_date: start_date.strftime('%Y-%m-%d'),
      end_date: end_date.strftime('%Y-%m-%d'),
      category_id: category_id,
      days: days_data,
      load_legend: {
        free: { min: 0, max: 30, color: '#4CAF50', label: 'Свободно' },
        medium: { min: 30, max: 70, color: '#FFC107', label: 'Средняя загрузка' },
        busy: { min: 70, max: 100, color: '#F44336', label: 'Почти занято' },
        unavailable: { color: '#9E9E9E', label: 'Недоступно' }
      }
    }
  end

  # GET /api/v1/service_points/:service_point_id/availability/:date/check
  # Быстрая проверка доступности дня (для календаря)
  def check_day_availability
    date = parse_date(params[:date])
    return if date.nil?
    
    category_id = params[:category_id]&.to_i
    
    begin
      if category_id.present?
        # Проверяем доступность для конкретной категории
        has_working_posts = DynamicAvailabilityService.send(:has_working_posts_for_category_on_date?, @service_point, date, category_id)
      else
        # Проверяем общую доступность (хотя бы один пост работает)
        has_working_posts = DynamicAvailabilityService.send(:has_any_working_posts_on_date?, @service_point, date)
      end
      
      render json: {
        service_point_id: @service_point.id,
        date: date.strftime('%Y-%m-%d'),
        is_available: has_working_posts,
        category_id: category_id
      }
    rescue => e
      render json: { error: "Внутренняя ошибка сервера: #{e.message}" }, status: :internal_server_error
    end
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

  # Calculate load indicator based on occupancy percentage
  # Returns: 'free', 'medium', 'busy', or 'unavailable'
  def calculate_load_indicator(occupancy_percent, is_working)
    return 'unavailable' unless is_working

    case occupancy_percent
    when 0..30 then 'free'
    when 31..70 then 'medium'
    else 'busy'
    end
  end
  
  # Метод для опционального получения текущего пользователя
  def try_get_current_user
    begin
      # Security: log only presence, never token values
      access_token = cookies.encrypted[:access_token]

      # Если нет в cookies, пробуем из заголовка Authorization (для обратной совместимости)
      if access_token.nil?
        header = request.headers['Authorization']
        access_token = header.split(' ').last if header
      end

      return nil if access_token.nil?

      decoded = Auth::JsonWebToken.decode(access_token)
      return nil unless decoded[:token_type] == 'access'

      user = User.find(decoded[:user_id])
      user&.is_active ? user : nil
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      nil
    rescue => e
      Rails.logger.error "try_get_current_user: #{e.class}"
      nil
    end
  end
end 