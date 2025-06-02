# Сервис для управления конфигурацией постов обслуживания
class ServicePostConfigurationService < ApplicationService
  
  # Вариант для работы через class методы (сохраняем обратную совместимость)
  # Создает стандартные посты для точки обслуживания
  def self.create_default_posts_for_service_point(service_point_id)
    new(service_point_id).create_default_posts
  end
  
  # Обновляет конфигурацию поста
  def self.update_post_configuration(service_post_id, params)
    new(service_post_id, params).update_configuration
  end
  
  # Деактивирует пост (помечает как неактивный)
  def self.deactivate_post(service_post_id)
    new(service_post_id).deactivate
  end
  
  # Активирует пост
  def self.activate_post(service_post_id)
    new(service_post_id).activate
  end
  
  # Получает статистику по постам
  def self.get_posts_statistics(service_point_id, date_from = 1.month.ago, date_to = Date.current)
    new(service_point_id).statistics(date_from, date_to)
  end
  
  # Instance методы
  def initialize(identifier, params = nil)
    @identifier = identifier # service_point_id или service_post_id
    @params = params
  end
  
  def call
    # Базовый метод - можно использовать для общих операций
    log_info "Вызван сервис конфигурации постов"
  end
  
  # Создает стандартные посты для точки обслуживания
  def create_default_posts
    service_point = ServicePoint.find(@identifier)
    
    # Получаем количество постов из существующих настроек
    post_count = service_point.post_count || 3
    default_duration = service_point.default_slot_duration || 60
    
    # Создаем посты по умолчанию
    (1..post_count).each do |post_number|
      next if service_point.service_posts.exists?(post_number: post_number)
      
      service_point.service_posts.create!(
        post_number: post_number,
        name: "Пост #{post_number}",
        slot_duration: default_duration,
        is_active: true,
        description: "Автоматически созданный пост обслуживания №#{post_number}"
      )
    end
    
    log_info "Созданы стандартные посты для точки обслуживания #{@identifier}"
    service_point.service_posts.reload
  rescue => error
    handle_error(error, "создание стандартных постов для точки #{@identifier}")
  end
  
  # Обновляет конфигурацию поста
  def update_configuration
    service_post = ServicePost.find(@identifier)
    
    # Проверяем, есть ли активные бронирования на этот пост
    active_bookings = service_post.service_point.bookings
                                   .joins(:schedule_slot)
                                   .where(schedule_slots: { slot_date: Date.current.. })
                                   .where.not(status: ['completed', 'canceled_by_client', 'canceled_by_partner'])
    
    if active_bookings.exists? && @params[:slot_duration] != service_post.slot_duration
      raise StandardError, "Нельзя изменить длительность слота при наличии активных бронирований"
    end
    
    service_post.update!(@params)
    
    # Пересоздаем расписание для будущих дат если изменилась длительность
    if @params[:slot_duration] && @params[:slot_duration] != service_post.slot_duration_was
      regenerate_future_schedule(service_post.service_point)
    end
    
    log_info "Обновлена конфигурация поста #{service_post.display_name}"
    service_post
  rescue => error
    handle_error(error, "обновление конфигурации поста #{@identifier}")
  end
  
  # Деактивирует пост
  def deactivate
    service_post = ServicePost.find(@identifier)
    
    # Проверяем активные бронирования
    active_bookings = service_post.service_point.bookings
                                   .joins(:schedule_slot)
                                   .where(schedule_slots: { slot_date: Date.current.. })
                                   .where.not(status: ['completed', 'canceled_by_client', 'canceled_by_partner'])
    
    if active_bookings.exists?
      raise StandardError, "Нельзя деактивировать пост при наличии активных бронирований"
    end
    
    service_post.update!(is_active: false)
    
    # Удаляем будущие слоты для этого поста
    remove_future_slots_for_post(service_post)
    
    log_info "Деактивирован пост #{service_post.display_name}"
    service_post
  rescue => error
    handle_error(error, "деактивация поста #{@identifier}")
  end
  
  # Активирует пост
  def activate
    service_post = ServicePost.find(@identifier)
    service_post.update!(is_active: true)
    
    # Пересоздаем расписание для будущих дат
    regenerate_future_schedule(service_post.service_point)
    
    log_info "Активирован пост #{service_post.display_name}"
    service_post
  rescue => error
    handle_error(error, "активация поста #{@identifier}")
  end
  
  # Получает статистику по постам
  def statistics(date_from, date_to)
    service_point = ServicePoint.find(@identifier)
    
    statistics = {}
    
    service_point.service_posts.active.each do |post|
      bookings = service_point.bookings
                              .joins(:schedule_slot)
                              .where(schedule_slots: { slot_date: date_from..date_to })
                              .where(status: 'completed')
      
      total_slots = service_point.schedule_slots
                                 .where(slot_date: date_from..date_to)
                                 .count
      
      booked_slots = bookings.count
      
      statistics[post.id] = {
        post_number: post.post_number,
        name: post.name,
        slot_duration: post.slot_duration,
        total_slots: total_slots,
        booked_slots: booked_slots,
        occupancy_rate: total_slots > 0 ? (booked_slots.to_f / total_slots * 100).round(2) : 0,
        revenue: bookings.sum(&:total_amount) || 0
      }
    end
    
    log_info "Получена статистика для точки обслуживания #{@identifier}"
    statistics
  rescue => error
    handle_error(error, "получение статистики для точки #{@identifier}")
  end
  
  private
  
  # Пересоздает расписание для будущих дат
  def regenerate_future_schedule(service_point)
    # Удаляем будущие слоты без бронирований
    service_point.schedule_slots
                 .where(slot_date: Date.current..)
                 .left_joins(:bookings)
                 .where(bookings: { id: nil })
                 .destroy_all
    
    # Генерируем новое расписание на следующие 30 дней
    end_date = Date.current + 30.days
    ScheduleManager.generate_slots_for_period(service_point.id, Date.current, end_date)
    
    log_info "Пересоздано расписание для точки #{service_point.name}"
  rescue => error
    log_error "Ошибка пересоздания расписания: #{error.message}"
  end
  
  # Удаляет будущие слоты для конкретного поста
  def remove_future_slots_for_post(service_post)
    # Эта логика будет реализована когда у нас будет связь слотов с постами
    # Пока удаляем все слоты и пересоздаем
    regenerate_future_schedule(service_post.service_point)
  end
end 