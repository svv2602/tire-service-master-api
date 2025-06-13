class Api::V1::DashboardController < Api::V1::ApiController
  # GET /api/v1/dashboard/stats
  def stats
    authorize :dashboard, :show?

    stats = {
      partners_count: Partner.active.count,
      service_points_count: ServicePoint.joins(:status).where(service_point_statuses: { name: 'active' }).count,
      clients_count: Client.joins(:user).where(users: { is_active: true }).count,
      bookings_count: Booking.count,
      completed_bookings_count: Booking.joins(:status).where(booking_statuses: { name: 'completed' }).count,
      canceled_bookings_count: Booking.joins(:status).where(booking_statuses: { name: ['canceled_by_client', 'canceled_by_partner'] }).count,
      bookings_by_month: bookings_by_month_data,
      revenue_by_month: revenue_by_month_data
    }

    render json: { data: stats }, status: :ok
  rescue => e
    Rails.logger.error "Dashboard stats error: #{e.message}"
    render json: { error: 'Не удалось загрузить статистику' }, status: :internal_server_error
  end

  # GET /api/v1/dashboard/charts/bookings
  def charts_bookings
    authorize :dashboard, :show?

    period = params[:period] || 'month'
    group_by = params[:group_by] || 'day'

    # Определяем период
    start_date = case period
                 when 'week' then 1.week.ago.beginning_of_day
                 when 'month' then 1.month.ago.beginning_of_day
                 when 'quarter' then 3.months.ago.beginning_of_day
                 when 'year' then 1.year.ago.beginning_of_day
                 else 1.month.ago.beginning_of_day
                 end

    # Получаем данные для графика
    bookings_data = get_bookings_chart_data(start_date, group_by)

    render json: { data: bookings_data }, status: :ok
  rescue => e
    Rails.logger.error "Dashboard bookings chart error: #{e.message}"
    render json: { error: 'Не удалось загрузить данные графика бронирований' }, status: :internal_server_error
  end

  # GET /api/v1/dashboard/charts/revenue
  def charts_revenue
    authorize :dashboard, :show?

    period = params[:period] || 'month'
    group_by = params[:group_by] || 'day'

    # Определяем период
    start_date = case period
                 when 'week' then 1.week.ago.beginning_of_day
                 when 'month' then 1.month.ago.beginning_of_day
                 when 'quarter' then 3.months.ago.beginning_of_day
                 when 'year' then 1.year.ago.beginning_of_day
                 else 1.month.ago.beginning_of_day
                 end

    # Получаем данные для графика
    revenue_data = get_revenue_chart_data(start_date, group_by)

    render json: { data: revenue_data }, status: :ok
  rescue => e
    Rails.logger.error "Dashboard revenue chart error: #{e.message}"
    render json: { error: 'Не удалось загрузить данные графика доходов' }, status: :internal_server_error
  end

  # GET /api/v1/dashboard/top-services
  def top_services
    authorize :dashboard, :show?

    limit = params[:limit] || 10
    period = params[:period] || 'month'

    # Определяем период
    start_date = case period
                 when 'week' then 1.week.ago.beginning_of_day
                 when 'month' then 1.month.ago.beginning_of_day
                 when 'quarter' then 3.months.ago.beginning_of_day
                 when 'year' then 1.year.ago.beginning_of_day
                 else 1.month.ago.beginning_of_day
                 end

    # Получаем топ услуг
    top_services_data = get_top_services_data(start_date, limit)

    render json: { data: top_services_data }, status: :ok
  rescue => e
    Rails.logger.error "Dashboard top services error: #{e.message}"
    render json: { error: 'Не удалось загрузить данные о популярных услугах' }, status: :internal_server_error
  end

  # GET /api/v1/dashboard/partner/:partner_id/stats
  def partner_stats
    partner = Partner.find(params[:partner_id])
    authorize :dashboard, :show_partner_stats?, partner: partner

    stats = {
      service_points_count: partner.service_points.joins(:status).where(service_point_statuses: { name: 'active' }).count,
      bookings_count: Booking.joins(service_point: :partner).where(service_points: { partner_id: partner.id }).count,
      completed_bookings_count: Booking.joins(:status, service_point: :partner)
                                      .where(booking_statuses: { name: 'completed' })
                                      .where(service_points: { partner_id: partner.id })
                                      .count,
      canceled_bookings_count: Booking.joins(:status, service_point: :partner)
                                     .where(booking_statuses: { name: ['canceled_by_client', 'canceled_by_partner'] })
                                     .where(service_points: { partner_id: partner.id })
                                     .count,
      revenue_total: Booking.joins(:status, service_point: :partner)
                          .where(booking_statuses: { name: 'completed' })
                          .where(service_points: { partner_id: partner.id })
                          .sum(:total_price),
      bookings_by_month: partner_bookings_by_month_data(partner.id),
      revenue_by_month: partner_revenue_by_month_data(partner.id)
    }

    render json: { data: stats }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Партнер не найден' }, status: :not_found
  rescue => e
    Rails.logger.error "Partner dashboard stats error: #{e.message}"
    render json: { error: 'Не удалось загрузить статистику партнера' }, status: :internal_server_error
  end

  private

  # Получаем данные о бронированиях по месяцам за последний год
  def bookings_by_month_data
    start_date = 12.months.ago.beginning_of_month
    end_date = Date.current.end_of_month
    
    bookings_by_month = Booking.where(bookings: { created_at: start_date..end_date })
                              .group("DATE_TRUNC('month', bookings.created_at)")
                              .count
    
    # Заполняем пропущенные месяцы нулями
    (0..11).map do |i|
      month = start_date + i.months
      bookings_by_month[month.beginning_of_month] || 0
    end
  end

  # Получаем данные о доходах по месяцам за последний год
  def revenue_by_month_data
    start_date = 12.months.ago.beginning_of_month
    end_date = Date.current.end_of_month
    
    revenue_by_month = Booking.joins(:status)
                             .where(booking_statuses: { name: 'completed' })
                             .where(bookings: { created_at: start_date..end_date })
                             .group("DATE_TRUNC('month', bookings.created_at)")
                             .sum(:total_price)
    
    # Заполняем пропущенные месяцы нулями
    (0..11).map do |i|
      month = start_date + i.months
      (revenue_by_month[month.beginning_of_month] || 0).to_f
    end
  end

  # Получаем данные о бронированиях партнера по месяцам за последний год
  def partner_bookings_by_month_data(partner_id)
    start_date = 12.months.ago.beginning_of_month
    end_date = Date.current.end_of_month
    
    bookings_by_month = Booking.joins(service_point: :partner)
                              .where(service_points: { partner_id: partner_id })
                              .where(bookings: { created_at: start_date..end_date })
                              .group("DATE_TRUNC('month', bookings.created_at)")
                              .count
    
    # Заполняем пропущенные месяцы нулями
    (0..11).map do |i|
      month = start_date + i.months
      bookings_by_month[month.beginning_of_month] || 0
    end
  end

  # Получаем данные о доходах партнера по месяцам за последний год
  def partner_revenue_by_month_data(partner_id)
    start_date = 12.months.ago.beginning_of_month
    end_date = Date.current.end_of_month
    
    revenue_by_month = Booking.joins(:status, service_point: :partner)
                             .where(booking_statuses: { name: 'completed' })
                             .where(service_points: { partner_id: partner_id })
                             .where(bookings: { created_at: start_date..end_date })
                             .group("DATE_TRUNC('month', bookings.created_at)")
                             .sum(:total_price)
    
    # Заполняем пропущенные месяцы нулями
    (0..11).map do |i|
      month = start_date + i.months
      (revenue_by_month[month.beginning_of_month] || 0).to_f
    end
  end

  # Получаем данные для графика бронирований
  def get_bookings_chart_data(start_date, group_by)
    end_date = Date.current.end_of_day
    
    # Определяем формат группировки
    date_format = case group_by
                  when 'day' then "DATE_TRUNC('day', bookings.created_at)"
                  when 'week' then "DATE_TRUNC('week', bookings.created_at)"
                  when 'month' then "DATE_TRUNC('month', bookings.created_at)"
                  else "DATE_TRUNC('day', bookings.created_at)"
                  end
    
    # Получаем данные о бронированиях по статусам
    completed_bookings = Booking.joins(:status)
                               .where(booking_statuses: { name: 'completed' })
                               .where(bookings: { created_at: start_date..end_date })
                               .group(date_format)
                               .count
    
    pending_bookings = Booking.joins(:status)
                             .where(booking_statuses: { name: 'pending' })
                             .where(bookings: { created_at: start_date..end_date })
                             .group(date_format)
                             .count
    
    canceled_bookings = Booking.joins(:status)
                              .where(booking_statuses: { name: ['canceled_by_client', 'canceled_by_partner'] })
                              .where(bookings: { created_at: start_date..end_date })
                              .group(date_format)
                              .count
    
    # Создаем массив дат для меток
    dates = []
    current_date = start_date
    
    while current_date <= end_date
      dates << case group_by
               when 'day' then current_date.strftime('%Y-%m-%d')
               when 'week' then "#{current_date.beginning_of_week.strftime('%Y-%m-%d')} - #{current_date.end_of_week.strftime('%Y-%m-%d')}"
               when 'month' then current_date.strftime('%Y-%m')
               else current_date.strftime('%Y-%m-%d')
               end
      
      current_date = case group_by
                     when 'day' then current_date + 1.day
                     when 'week' then current_date + 1.week
                     when 'month' then current_date + 1.month
                     else current_date + 1.day
                     end
    end
    
    # Формируем данные для графика
    completed_data = dates.map { |date| completed_bookings[date.to_date.beginning_of_day] || 0 }
    pending_data = dates.map { |date| pending_bookings[date.to_date.beginning_of_day] || 0 }
    canceled_data = dates.map { |date| canceled_bookings[date.to_date.beginning_of_day] || 0 }
    
    {
      labels: dates,
      datasets: [
        {
          label: 'Завершенные',
          data: completed_data,
          backgroundColor: '#4CAF50'
        },
        {
          label: 'Ожидающие',
          data: pending_data,
          backgroundColor: '#2196F3'
        },
        {
          label: 'Отмененные',
          data: canceled_data,
          backgroundColor: '#F44336'
        }
      ]
    }
  end

  # Получаем данные для графика доходов
  def get_revenue_chart_data(start_date, group_by)
    end_date = Date.current.end_of_day
    
    # Определяем формат группировки
    date_format = case group_by
                  when 'day' then "DATE_TRUNC('day', bookings.created_at)"
                  when 'week' then "DATE_TRUNC('week', bookings.created_at)"
                  when 'month' then "DATE_TRUNC('month', bookings.created_at)"
                  else "DATE_TRUNC('day', bookings.created_at)"
                  end
    
    # Получаем данные о доходах
    revenue_data = Booking.joins(:status)
                         .where(booking_statuses: { name: 'completed' })
                         .where(bookings: { created_at: start_date..end_date })
                         .group(date_format)
                         .sum(:total_price)
    
    # Создаем массив дат для меток
    dates = []
    current_date = start_date
    
    while current_date <= end_date
      dates << case group_by
               when 'day' then current_date.strftime('%Y-%m-%d')
               when 'week' then "#{current_date.beginning_of_week.strftime('%Y-%m-%d')} - #{current_date.end_of_week.strftime('%Y-%m-%d')}"
               when 'month' then current_date.strftime('%Y-%m')
               else current_date.strftime('%Y-%m-%d')
               end
      
      current_date = case group_by
                     when 'day' then current_date + 1.day
                     when 'week' then current_date + 1.week
                     when 'month' then current_date + 1.month
                     else current_date + 1.day
                     end
    end
    
    # Формируем данные для графика
    revenue_values = dates.map { |date| (revenue_data[date.to_date.beginning_of_day] || 0).to_f }
    
    {
      labels: dates,
      datasets: [
        {
          label: 'Доходы',
          data: revenue_values,
          backgroundColor: '#2196F3'
        }
      ]
    }
  end

  # Получаем данные о топ услугах
  def get_top_services_data(start_date, limit)
    # Получаем топ услуг на основе количества бронирований
    top_services = Service.joins(service_point_services: { service_point: :bookings })
                         .where(bookings: { created_at: start_date..Date.current.end_of_day })
                         .group('services.id')
                         .order('COUNT(bookings.id) DESC')
                         .limit(limit)
                         .select('services.id, services.name, services.description, services.price_min, services.price_max, COUNT(bookings.id) as bookings_count')
    
    # Формируем данные для ответа
    top_services.map do |service|
      {
        id: service.id,
        name: service.name,
        description: service.description,
        price_min: service.price_min,
        price_max: service.price_max,
        bookings_count: service.bookings_count
      }
    end
  end
end 