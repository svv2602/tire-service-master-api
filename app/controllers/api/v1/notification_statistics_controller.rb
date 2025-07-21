class Api::V1::NotificationStatisticsController < Api::V1::BaseController
  before_action :authenticate_request!
  before_action :ensure_admin!

  # GET /api/v1/notification_statistics/overview
  def overview
    # Общая статистика
    total_notifications = NotificationLog.count
    
    stats = {
      total_notifications: total_notifications,
      
      # Статистика по периодам
      today: {
        sent: NotificationLog.today.sent.count,
        delivered: NotificationLog.today.delivered.count,
        failed: NotificationLog.today.failed.count,
        opened: NotificationLog.today.opened.count
      },
      
      this_week: {
        sent: NotificationLog.this_week.sent.count,
        delivered: NotificationLog.this_week.delivered.count,
        failed: NotificationLog.this_week.failed.count,
        opened: NotificationLog.this_week.opened.count
      },
      
      this_month: {
        sent: NotificationLog.this_month.sent.count,
        delivered: NotificationLog.this_month.delivered.count,
        failed: NotificationLog.this_month.failed.count,
        opened: NotificationLog.this_month.opened.count
      },
      
      # Общие метрики
      success_rate: NotificationLog.success_rate,
      open_rate: NotificationLog.open_rate,
      click_rate: NotificationLog.click_rate,
      bounce_rate: NotificationLog.bounce_rate,
      
      # Статистика по типам уведомлений
      by_notification_type: NotificationLog.group(:notification_type).count,
      by_template_type: NotificationLog.group(:template_type).count,
      by_status: NotificationLog.group(:status).count,
      
      # Топ получателей
      top_recipients: NotificationLog
        .group(:recipient_email)
        .count
        .sort_by { |_, count| -count }
        .first(10)
        .map { |email, count| { email: email, count: count } },
      
      # Последние неудачные отправки
      recent_failures: NotificationLog
        .failed
        .order(created_at: :desc)
        .limit(5)
        .map { |log| serialize_notification_log(log) }
    }
    
    render json: { statistics: stats }
  end

  # GET /api/v1/notification_statistics/daily
  def daily
    days = params[:days]&.to_i || 30
    days = [days, 90].min # Максимум 90 дней
    
    daily_stats = NotificationLog.stats_by_day(days)
    
    # Преобразуем в удобный формат для графиков
    chart_data = {}
    
    (days.days.ago.to_date..Date.current).each do |date|
      date_str = date.strftime('%Y-%m-%d')
      chart_data[date_str] = {
        date: date_str,
        sent: daily_stats[[date_str, 'sent']] || 0,
        delivered: daily_stats[[date_str, 'delivered']] || 0,
        failed: daily_stats[[date_str, 'failed']] || 0,
        opened: daily_stats[[date_str, 'opened']] || 0,
        clicked: daily_stats[[date_str, 'clicked']] || 0
      }
    end
    
    render json: {
      daily_statistics: chart_data.values,
      period: "#{days} дней",
      total_days: days
    }
  end

  # GET /api/v1/notification_statistics/hourly
  def hourly
    hours = params[:hours]&.to_i || 24
    hours = [hours, 168].min # Максимум неделя
    
    hourly_stats = NotificationLog.stats_by_hour(hours)
    
    # Преобразуем в удобный формат
    chart_data = {}
    
    hours.times do |i|
      hour_time = i.hours.ago.beginning_of_hour
      hour_str = hour_time.strftime('%Y-%m-%d %H:00:00')
      
      chart_data[hour_str] = {
        datetime: hour_str,
        hour: hour_time.strftime('%H:00'),
        date: hour_time.strftime('%d.%m'),
        sent: hourly_stats[[hour_time, 'sent']] || 0,
        delivered: hourly_stats[[hour_time, 'delivered']] || 0,
        failed: hourly_stats[[hour_time, 'failed']] || 0,
        opened: hourly_stats[[hour_time, 'opened']] || 0
      }
    end
    
    render json: {
      hourly_statistics: chart_data.values.reverse,
      period: "#{hours} часов",
      total_hours: hours
    }
  end

  # GET /api/v1/notification_statistics/templates
  def templates
    template_stats = NotificationLog
      .joins(:template)
      .group('email_templates.name', :template_type, :status)
      .count
    
    # Группируем по шаблонам
    templates_data = {}
    
    template_stats.each do |(name, type, status), count|
      key = "#{name} (#{type})"
      templates_data[key] ||= {
        name: name,
        type: type,
        total: 0,
        sent: 0,
        delivered: 0,
        failed: 0,
        opened: 0,
        clicked: 0
      }
      
      templates_data[key][status.to_sym] = count
      templates_data[key][:total] += count
    end
    
    # Вычисляем метрики для каждого шаблона
    templates_data.each do |_, data|
      if data[:total] > 0
        data[:success_rate] = (data[:delivered].to_f / data[:total] * 100).round(2)
        data[:open_rate] = data[:delivered] > 0 ? (data[:opened].to_f / data[:delivered] * 100).round(2) : 0
        data[:click_rate] = data[:delivered] > 0 ? (data[:clicked].to_f / data[:delivered] * 100).round(2) : 0
      end
    end
    
    render json: {
      template_statistics: templates_data.values.sort_by { |t| -t[:total] },
      total_templates: templates_data.count
    }
  end

  # GET /api/v1/notification_statistics/recipients
  def recipients
    recipient_stats = NotificationLog
      .group(:recipient_type, :recipient_email)
      .group(:status)
      .count
    
    # Группируем по получателям
    recipients_data = {}
    
    recipient_stats.each do |(type, email, status), count|
      key = "#{type}:#{email}"
      recipients_data[key] ||= {
        recipient_type: type,
        recipient_email: email,
        total: 0,
        sent: 0,
        delivered: 0,
        failed: 0,
        opened: 0,
        clicked: 0
      }
      
      recipients_data[key][status.to_sym] = count
      recipients_data[key][:total] += count
    end
    
    # Сортируем по количеству уведомлений
    sorted_recipients = recipients_data.values.sort_by { |r| -r[:total] }
    
    render json: {
      recipient_statistics: sorted_recipients.first(50), # Топ 50 получателей
      total_recipients: recipients_data.count
    }
  end

  # GET /api/v1/notification_statistics/failures
  def failures
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 20, 100].min
    
    failures = NotificationLog
      .failed
      .includes(:template)
      .order(created_at: :desc)
      .page(page)
      .per(per_page)
    
    # Группируем ошибки по типам
    error_types = NotificationLog
      .failed
      .where.not(error_message: nil)
      .group(:error_message)
      .count
      .sort_by { |_, count| -count }
      .first(10)
    
    render json: {
      failures: failures.map { |log| serialize_notification_log(log, detailed: true) },
      pagination: {
        current_page: failures.current_page,
        total_pages: failures.total_pages,
        total_count: failures.total_count,
        per_page: per_page
      },
      error_types: error_types.map { |msg, count| { message: msg, count: count } },
      total_failures: NotificationLog.failed.count
    }
  end

  # GET /api/v1/notification_statistics/performance
  def performance
    # Статистика производительности
    avg_response_times = NotificationLog
      .where.not(sent_at: nil, delivered_at: nil)
      .pluck(:sent_at, :delivered_at)
      .map { |sent, delivered| delivered - sent }
      .select { |time| time > 0 }
    
    performance_stats = {
      total_processed: NotificationLog.count,
      
      # Времена отклика
      average_response_time: avg_response_times.any? ? (avg_response_times.sum / avg_response_times.count).round(2) : 0,
      max_response_time: avg_response_times.any? ? avg_response_times.max.round(2) : 0,
      min_response_time: avg_response_times.any? ? avg_response_times.min.round(2) : 0,
      
      # Статистика по часам дня (когда больше всего отправляется)
      hourly_distribution: NotificationLog
        .where(sent_at: 30.days.ago..Time.current)
        .group("EXTRACT(hour FROM sent_at)")
        .count
        .transform_keys { |hour| "#{hour.to_i}:00" },
      
      # Статистика по дням недели
      weekday_distribution: NotificationLog
        .where(sent_at: 30.days.ago..Time.current)
        .group("EXTRACT(dow FROM sent_at)")
        .count
        .transform_keys do |dow|
          %w[Воскресенье Понедельник Вторник Среда Четверг Пятница Суббота][dow.to_i]
        end,
      
      # Топ часы для открытий
      peak_open_hours: NotificationLog
        .opened
        .where(opened_at: 30.days.ago..Time.current)
        .group("EXTRACT(hour FROM opened_at)")
        .count
        .sort_by { |_, count| -count }
        .first(5)
        .map { |hour, count| { hour: "#{hour.to_i}:00", count: count } }
    }
    
    render json: { performance_statistics: performance_stats }
  end

  private

  def serialize_notification_log(log, detailed: false)
    data = {
      id: log.id,
      notification_type: log.notification_type,
      template_type: log.template_type,
      recipient_email: log.recipient_email,
      status: log.status,
      status_text: log.status_text,
      status_color: log.status_color,
      sent_at: log.sent_at,
      created_at: log.created_at
    }
    
    if detailed
      data.merge!({
        delivered_at: log.delivered_at,
        opened_at: log.opened_at,
        clicked_at: log.clicked_at,
        error_message: log.error_message,
        metadata: log.metadata,
        response_time: log.response_time,
        time_to_open: log.time_to_open,
        template_name: log.template&.name
      })
    end
    
    data
  end
end 