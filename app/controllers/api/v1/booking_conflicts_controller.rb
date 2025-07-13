class Api::V1::BookingConflictsController < ApplicationController
  before_action :authenticate_request
  before_action :authorize_admin_or_partner
  before_action :set_booking_conflict, only: [:show, :resolve, :ignore]

  # GET /api/v1/booking_conflicts
  def index
    @booking_conflicts = policy_scope(BookingConflict)
                        .includes(booking: [:service_point, :service_category, :client])
                        .includes(:resolved_by)

    # Фильтрация
    @booking_conflicts = @booking_conflicts.where(status: params[:status]) if params[:status].present?
    @booking_conflicts = @booking_conflicts.by_conflict_type(params[:conflict_type]) if params[:conflict_type].present?
    @booking_conflicts = @booking_conflicts.for_service_point(params[:service_point_id]) if params[:service_point_id].present?

    # Сортировка
    @booking_conflicts = @booking_conflicts.recent

    # Пагинация
    page = [params[:page].to_i, 1].max  # Минимум 1
    per_page = [params[:per_page].to_i, 20].max  # Минимум 20
    per_page = [per_page, 100].min # Ограничиваем максимум 100 записей на страницу
    
    offset = (page - 1) * per_page
    total_count = @booking_conflicts.count
    @booking_conflicts = @booking_conflicts.limit(per_page).offset(offset)

    render json: {
      booking_conflicts: @booking_conflicts.map { |conflict| serialize_conflict(conflict) },
      meta: {
        current_page: page,
        total_pages: (total_count.to_f / per_page).ceil,
        total_count: total_count,
        per_page: per_page
      }
    }
  end

  # GET /api/v1/booking_conflicts/:id
  def show
    render json: { booking_conflict: serialize_conflict(@booking_conflict) }
  end

  # GET /api/v1/booking_conflicts/statistics
  def statistics
    stats = BookingConflictAnalysisService.conflict_statistics
    render json: { statistics: stats }
  end

  # POST /api/v1/booking_conflicts/analyze
  def analyze
    service_point_id = params[:service_point_id]
    post_id = params[:post_id]
    seasonal_schedule_id = params[:seasonal_schedule_id]

    # Запускаем асинхронный анализ
    BookingConflictAnalysisJob.perform_later(
      service_point_id: service_point_id,
      post_id: post_id,
      seasonal_schedule_id: seasonal_schedule_id
    )

    render json: { message: 'Анализ конфликтов запущен' }
  end

  # POST /api/v1/booking_conflicts/preview
  def preview
    service_point = ServicePoint.find(params[:service_point_id]) if params[:service_point_id].present?
    post = ServicePointPost.find(params[:post_id]) if params[:post_id].present?
    seasonal_schedule = SeasonalSchedule.find(params[:seasonal_schedule_id]) if params[:seasonal_schedule_id].present?

    conflicts = BookingConflictAnalysisService.preview_conflicts(
      service_point: service_point,
      post: post,
      seasonal_schedule: seasonal_schedule
    )

    render json: {
      conflicts: conflicts.map { |conflict| serialize_conflict(conflict) },
      count: conflicts.count
    }
  end

  # POST /api/v1/booking_conflicts/preview_with_form_data
  def preview_with_form_data
    service_point_id = params[:service_point_id]
    form_data = params[:form_data]

    unless service_point_id.present? && form_data.present?
      return render json: { error: 'service_point_id и form_data обязательны' }, status: :bad_request
    end

    # Создаем временную копию сервисной точки с данными формы
    temp_service_point = build_temp_service_point_with_form_data(service_point_id, form_data)

    # Анализируем конфликты с временными данными
    conflicts = BookingConflictAnalysisService.preview_conflicts_with_temp_data(
      temp_service_point: temp_service_point
    )

    render json: {
      conflicts: conflicts.map { |conflict| serialize_conflict(conflict) },
      count: conflicts.count,
      preview_mode: true,
      form_data_applied: true
    }
  end

  # POST /api/v1/booking_conflicts/:id/resolve
  def resolve
    resolution_type = params[:resolution_type]
    notes = params[:notes]

    unless BookingConflict::RESOLUTION_TYPES.include?(resolution_type)
      return render json: { error: 'Неверный тип разрешения' }, status: :unprocessable_entity
    end

    result = case resolution_type
    when 'auto_reschedule'
      handle_auto_reschedule
    when 'manual_reschedule'
      handle_manual_reschedule
    when 'cancel'
      handle_cancel_booking
    else
      @booking_conflict.resolve!(
        resolution_type: resolution_type,
        resolved_by: current_user,
        notes: notes
      )
      true
    end

    # Если один из handle методов уже отрендерил ответ, не рендерим повторно
    return if result == :rendered

    render json: { 
      message: 'Конфликт разрешен',
      booking_conflict: serialize_conflict(@booking_conflict.reload)
    }
  end

  # POST /api/v1/booking_conflicts/:id/ignore
  def ignore
    notes = params[:notes]

    @booking_conflict.ignore!(
      resolved_by: current_user,
      notes: notes
    )

    render json: { 
      message: 'Конфликт игнорирован',
      booking_conflict: serialize_conflict(@booking_conflict.reload)
    }
  end

  # POST /api/v1/booking_conflicts/bulk_resolve
  def bulk_resolve
    conflict_ids = params[:conflict_ids]
    resolution_type = params[:resolution_type]
    notes = params[:notes]

    unless BookingConflict::RESOLUTION_TYPES.include?(resolution_type)
      return render json: { error: 'Неверный тип разрешения' }, status: :unprocessable_entity
    end

    conflicts = BookingConflict.where(id: conflict_ids).pending
    results = []

    conflicts.each do |conflict|
      begin
        case resolution_type
        when 'auto_reschedule'
          handle_auto_reschedule_for_conflict(conflict)
        when 'manual_reschedule'
          # Для массового переноса используем автоматический перенос
          handle_auto_reschedule_for_conflict(conflict)
        when 'cancel'
          handle_cancel_booking_for_conflict(conflict)
        else
          conflict.resolve!(
            resolution_type: resolution_type,
            resolved_by: current_user,
            notes: notes
          )
        end
        results << { id: conflict.id, status: 'resolved' }
      rescue StandardError => e
        results << { id: conflict.id, status: 'error', error: e.message }
      end
    end

    render json: { 
      message: 'Массовое разрешение конфликтов завершено',
      results: results
    }
  end

  private

  def set_booking_conflict
    @booking_conflict = BookingConflict.find(params[:id])
    authorize @booking_conflict
  end

  def authorize_admin_or_partner
    unless current_user&.admin? || current_user&.partner?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end

  def build_temp_service_point_with_form_data(service_point_id, form_data)
    # Загружаем исходную сервисную точку
    original_service_point = ServicePoint.find(service_point_id)
    
    # Создаем временную копию с использованием OpenStruct для гибкости
    temp_service_point = OpenStruct.new(original_service_point.attributes)
    
    # Применяем данные формы
    if form_data[:working_hours].present?
      temp_service_point.working_hours = form_data[:working_hours]
    end
    
    # Обрабатываем посты обслуживания
    if form_data[:service_posts_attributes].present?
      temp_posts = []
      
      form_data[:service_posts_attributes].each do |post_data|
        if post_data[:id].present?
          # Обновляем существующий пост
          original_post = original_service_point.service_posts.find(post_data[:id])
          temp_post = OpenStruct.new(original_post.attributes)
          
          # Применяем изменения из формы
          temp_post.name = post_data[:name] if post_data[:name].present?
          temp_post.slot_duration = post_data[:slot_duration].to_i if post_data[:slot_duration].present?
          temp_post.is_active = post_data[:is_active] if post_data.key?(:is_active)
          temp_post.post_number = post_data[:post_number].to_i if post_data[:post_number].present?
          temp_post.service_category_id = post_data[:service_category_id].to_i if post_data[:service_category_id].present?
          temp_post.has_custom_schedule = post_data[:has_custom_schedule] if post_data.key?(:has_custom_schedule)
          temp_post.working_days = post_data[:working_days] if post_data[:working_days].present?
          temp_post.custom_hours = post_data[:custom_hours] if post_data[:custom_hours].present?
          
          # Добавляем ссылку на сервисную точку
          temp_post.service_point = temp_service_point
          
          temp_posts << temp_post unless post_data[:_destroy]
        elsif !post_data[:_destroy]
          # Создаем новый пост
          temp_post = OpenStruct.new(
            id: nil,
            name: post_data[:name],
            slot_duration: post_data[:slot_duration].to_i,
            is_active: post_data[:is_active] || true,
            post_number: post_data[:post_number].to_i,
            service_category_id: post_data[:service_category_id].to_i,
            has_custom_schedule: post_data[:has_custom_schedule] || false,
            working_days: post_data[:working_days] || {},
            custom_hours: post_data[:custom_hours] || {},
            service_point: temp_service_point
          )
          
          temp_posts << temp_post
        end
      end
      
      # Создаем коллекцию постов с методом active
      posts_collection = temp_posts
      
      # Создаем объект-обертку с необходимыми методами
      service_posts_wrapper = Object.new
      service_posts_wrapper.define_singleton_method(:active) do
        posts_collection.select { |post| post.is_active }
      end
      
      service_posts_wrapper.define_singleton_method(:each) do |&block|
        posts_collection.each(&block)
      end
      
      service_posts_wrapper.define_singleton_method(:to_a) do
        posts_collection
      end
      
      service_posts_wrapper.define_singleton_method(:count) do
        posts_collection.count
      end
      
      temp_service_point.service_posts = service_posts_wrapper
    end
    
    temp_service_point
  end

  def serialize_conflict(conflict)
    booking = conflict.booking
    client_info = if booking.client.present?
      {
        id: booking.client.id,
        name: booking.client.user&.full_name || "#{booking.client.user&.first_name} #{booking.client.user&.last_name}".strip,
        email: booking.client.user&.email
      }
    else
      # Fallback для бронирований без клиента (гостевые или сервисные)
      {
        id: nil,
        name: booking.service_recipient_full_name || "#{booking.service_recipient_first_name} #{booking.service_recipient_last_name}".strip,
        email: booking.service_recipient_email
      }
    end

    # Правильное объединение даты и времени
    booking_start_datetime = if booking.booking_date && booking.start_time
      Time.zone.parse("#{booking.booking_date} #{booking.start_time}")
    else
      nil
    end

    {
      id: conflict.id,
      conflict_type: conflict.conflict_type,
      conflict_type_human: conflict.conflict_type_human,
      conflict_reason: conflict.conflict_reason,
      status: conflict.status,
      status_human: conflict.status_human,
      detected_at: conflict.detected_at,
      resolved_at: conflict.resolved_at,
      resolution_type: conflict.resolution_type,
      resolution_type_human: conflict.resolution_type_human,
      resolution_notes: conflict.resolution_notes,
      resolved_by: conflict.resolved_by&.full_name,
      booking: {
        id: booking.id,
        start_time: booking_start_datetime,
        service_point: {
          id: booking.service_point.id,
          name: booking.service_point.name
        },
        service_category: {
          id: booking.service_category&.id,
          name: booking.service_category&.name
        },
        client: client_info
      }
    }
  end

  def handle_auto_reschedule
    handle_auto_reschedule_for_conflict(@booking_conflict)
    true
  end

  def handle_auto_reschedule_for_conflict(conflict)
    booking = conflict.booking
    
    # Ищем доступные слоты на следующие 7 дней
    7.times do |days_offset|
      check_date = booking.booking_date + days_offset.days
      
      # Используем статический метод для получения доступных слотов для категории
      available_slots = DynamicAvailabilityService.available_slots_for_category(
        booking.service_point.id,
        check_date,
        booking.service_category_id
      )
      
      if available_slots.any?
        new_slot = available_slots.first
        
        # Обновляем бронирование - правильно разделяем дату и время
        booking.update!(
          booking_date: check_date, 
          start_time: new_slot[:start_time] + ':00'
        )
        
        # Разрешаем конфликт
        conflict.resolve!(
          resolution_type: 'auto_reschedule',
          resolved_by: current_user,
          notes: "Автоматически перенесено на #{check_date.strftime('%d.%m.%Y')} #{new_slot[:start_time]}"
        )
        
        # Отправляем уведомление клиенту
        send_reschedule_notification(booking, conflict)
        return
      end
    end
    
    # Если не найден доступный слот, помечаем как требующий ручного вмешательства
    conflict.update!(
      resolution_notes: 'Не удалось найти доступный слот для автоматического переноса'
    )
  end

  def handle_manual_reschedule
    new_start_time = Time.zone.parse(params[:new_start_time])
    booking = @booking_conflict.booking
    
    # Проверяем доступность нового слота ТОЛЬКО для клиентов
    # Администраторы, партнеры, операторы и менеджеры могут назначать любое время
    if current_user&.client?
      available_slots = DynamicAvailabilityService.available_slots_for_category(
        booking.service_point.id,
        new_start_time.to_date,
        booking.service_category_id
      )
      
      slot_time = new_start_time.strftime('%H:%M')
      
      unless available_slots.any? { |slot| slot[:start_time] == slot_time }
        render json: { error: 'Выбранный слот недоступен' }, status: :unprocessable_entity
        return :rendered
      end
    end
    
    # Обновляем бронирование - и дату и время
    booking.update!(
      booking_date: new_start_time.to_date,
      start_time: new_start_time.strftime('%H:%M:%S')
    )
    
    # Разрешаем конфликт
    @booking_conflict.resolve!(
      resolution_type: 'manual_reschedule',
      resolved_by: current_user,
      notes: "Вручную перенесено на #{new_start_time.strftime('%d.%m.%Y %H:%M')}"
    )
    
    # Отправляем уведомление клиенту
    send_reschedule_notification(booking, @booking_conflict)
    
    true
  end

  def handle_cancel_booking
    handle_cancel_booking_for_conflict(@booking_conflict)
    true
  end

  def handle_cancel_booking_for_conflict(conflict)
    booking = conflict.booking
    
    # Отменяем бронирование с использованием правильного метода
    booking.cancel_by_partner!
    
    # Разрешаем конфликт
    conflict.resolve!(
      resolution_type: 'cancel',
      resolved_by: current_user,
      notes: 'Бронирование отменено из-за конфликта расписания'
    )
    
    # Отправляем уведомление клиенту
    send_cancellation_notification(booking, conflict)
  end

  def send_reschedule_notification(booking, conflict)
    return unless booking.client&.user&.email.present?
    
    NotificationMailer.booking_rescheduled(booking, conflict).deliver_later
  end

  def send_cancellation_notification(booking, conflict)
    return unless booking.client&.user&.email.present?
    
    NotificationMailer.booking_cancelled_due_to_conflict(booking, conflict).deliver_later
  end
end 