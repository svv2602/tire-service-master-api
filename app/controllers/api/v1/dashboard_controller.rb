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
end 