class Api::V1::AuditLogsController < ApplicationController
  before_action :authenticate_request
  before_action :authorize_audit_access

  # GET /api/v1/audit_logs
  # Получить список аудит логов с фильтрами
  def index
    @logs = policy_scope(SystemLog).includes(:user).order(created_at: :desc)
    
    # Применяем фильтры
    @logs = apply_filters(@logs)
    
    # Пагинация (простая реализация без Kaminari)
    page = [params[:page]&.to_i || 1, 1].max
    per_page = [params[:per_page]&.to_i || 50, 100].min # Максимум 100 записей
    
    total_count = @logs.count
    total_pages = (total_count.to_f / per_page).ceil
    offset = (page - 1) * per_page
    
    @logs = @logs.limit(per_page).offset(offset)
    
          render json: {
        data: @logs.map { |log| serialize_audit_log(log) },
        meta: {
          current_page: page,
          total_pages: total_pages,
          total_count: total_count,
          per_page: per_page,
          filters_applied: applied_filters_info
        }
      }
  end

  # GET /api/v1/audit_logs/stats
  # Получить статистику по аудит логам
  def stats
    days_ago = [params[:days]&.to_i || 30, 365].min # Максимум год
    
    stats_data = {
      period: {
        days: days_ago,
        from: days_ago.days.ago.to_date,
        to: Date.current
      },
      
      # Общая статистика
      total_logs: SystemLog.where('created_at >= ?', days_ago.days.ago).count,
      
      # По типам действий
      actions: SystemLog.stats_by_action(days_ago),
      
      # По пользователям (топ 10)
      top_users: SystemLog.stats_by_user(days_ago)
                           .sort_by { |_, count| -count }
                           .first(10)
                           .map { |email, count| { email: email, actions_count: count } },
      
      # По ресурсам
      resources: SystemLog.most_active_resources(days_ago, 10)
                          .map { |resource_type, count| { resource_type: resource_type, changes_count: count } },
      
      # Активность по дням (последние 14 дней)
      daily_activity: daily_activity_stats(days_ago),
      
      # Статистика по часам (последние 24 часа)
      hourly_activity: hourly_activity_stats,
      
      # Топ IP адресов
      top_ips: top_ip_addresses(days_ago),
      
      # Статистика по типам ресурсов и действиям
      action_resource_matrix: action_resource_matrix(days_ago)
    }
    
    render json: {
      data: stats_data,
      generated_at: Time.current.iso8601
    }
  end

  # GET /api/v1/audit_logs/:id
  # Получить детальную информацию о конкретном аудит логе
  def show
    @log = SystemLog.find(params[:id])
    authorize @log, :show?
    
    render json: {
      data: serialize_audit_log(@log, detailed: true)
    }
  end

  # GET /api/v1/audit_logs/export
  # Экспорт аудит логов в CSV
  def export
    authorize SystemLog, :export?
    
    @logs = policy_scope(SystemLog).includes(:user).order(created_at: :desc)
    @logs = apply_filters(@logs)
    
    # Ограничиваем экспорт максимум 10000 записей
    @logs = @logs.limit(10000)
    
    respond_to do |format|
      format.csv do
        csv_data = generate_csv_export(@logs)
        send_data csv_data, 
                  filename: "audit_logs_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv'
      end
      
      format.json do
        render json: {
          message: 'Для экспорта используйте формат CSV',
          example_url: "#{request.base_url}#{request.path}.csv?#{request.query_string}"
        }
      end
    end
  end

  # GET /api/v1/audit_logs/search_autocomplete
  # Автокомплит для поиска в аудит логах
  def search_autocomplete
    authorize SystemLog, :index?
    
    field = params[:field]
    query = params[:query]&.strip
    
    return render json: { suggestions: [] } if query.blank? || field.blank?
    
    suggestions = case field
    when 'user_email'
      autocomplete_users(query)
    when 'resource_type'
      autocomplete_resource_types(query)
    when 'action'
      autocomplete_actions(query)
    when 'ip_address'
      autocomplete_ip_addresses(query)
    when 'resource_name'
      autocomplete_resource_names(query)
    else
      []
    end
    
    render json: { 
      field: field,
      query: query,
      suggestions: suggestions.first(10) # Ограничиваем 10 результатами
    }
  end

  # GET /api/v1/audit_logs/suspicious_activity
  # Обнаружение подозрительной активности
  def suspicious_activity
    authorize SystemLog, :index?
    
    days_ago = [params[:days]&.to_i || 7, 30].min
    
    suspicious_patterns = {
      # Частые неудачные попытки входа
      frequent_failed_logins: detect_frequent_failed_logins(days_ago),
      
      # Множественные входы с разных IP
      multiple_ip_logins: detect_multiple_ip_logins(days_ago),
      
      # Массовые изменения данных
      bulk_data_changes: detect_bulk_data_changes(days_ago),
      
      # Подозрительные IP адреса
      suspicious_ips: detect_suspicious_ips(days_ago),
      
      # Активность в нерабочее время
      off_hours_activity: detect_off_hours_activity(days_ago),
      
      # Необычные паттерны доступа
      unusual_access_patterns: detect_unusual_access_patterns(days_ago)
    }
    
    render json: {
      period: {
        days: days_ago,
        from: days_ago.days.ago.to_date,
        to: Date.current
      },
      suspicious_activity: suspicious_patterns,
      generated_at: Time.current.iso8601
    }
  end

  # GET /api/v1/audit_logs/user_timeline/:user_id
  # Временная шкала действий пользователя
  def user_timeline
    user = User.find(params[:user_id])
    authorize user, :show?
    
    days_ago = [params[:days]&.to_i || 30, 90].min
    
    timeline_data = SystemLog.where(user: user)
                            .where('created_at >= ?', days_ago.days.ago)
                            .order(created_at: :desc)
                            .limit(500)
                            .map { |log| serialize_timeline_event(log) }
                            .group_by { |event| event[:date] }
    
    render json: {
      user: {
        id: user.id,
        name: user.full_name,
        email: user.email,
        role: user.role
      },
      period: {
        days: days_ago,
        from: days_ago.days.ago.to_date,
        to: Date.current
      },
      timeline: timeline_data,
      total_events: timeline_data.values.flatten.count
    }
  end

  # GET /api/v1/audit_logs/resource_history/:resource_type/:resource_id
  # История изменений конкретного ресурса
  def resource_history
    authorize SystemLog, :show?
    
    resource_type = params[:resource_type]
    resource_id = params[:resource_id]
    
    history = SystemLog.where(resource_type: resource_type, resource_id: resource_id)
                      .includes(:user)
                      .order(created_at: :desc)
                      .limit(100)
                      .map { |log| serialize_audit_log(log, detailed: true) }
    
    # Попытаемся получить информацию о ресурсе
    resource_info = get_resource_info(resource_type, resource_id)
    
    render json: {
      resource: resource_info,
      history: history,
      total_changes: history.count
    }
  end

  # POST /api/v1/audit_logs/manual_log
  # Ручное создание лога аудита (для критичных операций)
  def manual_log
    authorize SystemLog, :create?
    
    log_params = params.require(:log).permit(
      :action, :resource_type, :resource_id, :description, :additional_data
    )
    
    # Создаем лог через Job для консистентности
    AuditLogJob.perform_later(
      action: log_params[:action] || 'manual_entry',
      user_id: current_user.id,
      resource_type: log_params[:resource_type],
      resource_id: log_params[:resource_id],
      additional_data: {
        manual_entry: true,
        description: log_params[:description],
        custom_data: log_params[:additional_data]
      },
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
    
    render json: {
      message: 'Запись аудита создана',
      status: 'queued'
    }, status: :created
  end

  private

  def authorize_audit_access
    authorize SystemLog, :index?
  end

  def apply_filters(logs)
    # Фильтр по пользователю
    if params[:user_id].present?
      logs = logs.where(user_id: params[:user_id])
    end
    
    if params[:user_email].present?
      logs = logs.joins(:user).where('users.email ILIKE ?', "%#{params[:user_email]}%")
    end
    
    # Фильтр по действию
    if params[:action].present?
      actions = params[:action].split(',').map(&:strip)
      logs = logs.where(action: actions)
    end
    
    # Фильтр по типу ресурса
    if params[:resource_type].present?
      resource_types = params[:resource_type].split(',').map(&:strip)
      logs = logs.where(resource_type: resource_types)
    end
    
    # Фильтр по ID ресурса
    if params[:resource_id].present?
      logs = logs.where(resource_id: params[:resource_id])
    end
    
    # Фильтр по дате
    if params[:date_from].present?
      begin
        date_from = Date.parse(params[:date_from]).beginning_of_day
        logs = logs.where('created_at >= ?', date_from)
      rescue Date::Error
        # Игнорируем некорректную дату
      end
    end
    
    if params[:date_to].present?
      begin
        date_to = Date.parse(params[:date_to]).end_of_day
        logs = logs.where('created_at <= ?', date_to)
      rescue Date::Error
        # Игнорируем некорректную дату
      end
    end
    
    # Фильтр по IP адресу
    if params[:ip_address].present?
      logs = logs.where('ip_address::text ILIKE ?', "%#{params[:ip_address]}%")
    end
    
    logs
  end

  def applied_filters_info
    filters = {}
    
    filters[:user_id] = params[:user_id] if params[:user_id].present?
    filters[:user_email] = params[:user_email] if params[:user_email].present?
    filters[:action] = params[:action] if params[:action].present?
    filters[:resource_type] = params[:resource_type] if params[:resource_type].present?
    filters[:resource_id] = params[:resource_id] if params[:resource_id].present?
    filters[:date_from] = params[:date_from] if params[:date_from].present?
    filters[:date_to] = params[:date_to] if params[:date_to].present?
    filters[:ip_address] = params[:ip_address] if params[:ip_address].present?
    
    filters
  end

  def serialize_audit_log(log, detailed: false)
    base_data = {
      id: log.id,
      user_id: log.user_id,
      user_name: log.user&.full_name || 'Система',
      user_email: log.user&.email,
      action: log.action,
      action_description: log.action_description,
      resource_type: log.resource_type,
      resource_id: log.resource_id,
      resource_name: log.resource_name,
      ip_address: log.ip_address,
      created_at: log.created_at.iso8601
    }
    
    if detailed
      base_data.merge!({
        old_value: log.old_value,
        new_value: log.new_value,
        changes: log.changes,
        additional_data: log.additional_data,
        user_agent: log.user_agent,
        updated_at: log.updated_at.iso8601
      })
    end
    
    base_data
  end

  def daily_activity_stats(days_ago)
    end_date = Date.current
    start_date = [days_ago.days.ago.to_date, end_date - 13.days].max
    
    SystemLog.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
             .group("DATE(created_at)")
             .count
             .map { |date, count| { date: date, count: count } }
             .sort_by { |item| item[:date] }
  end

  def hourly_activity_stats
    start_time = 24.hours.ago
    
    SystemLog.where(created_at: start_time..Time.current)
             .group("EXTRACT(hour FROM created_at)")
             .count
             .map { |hour, count| { hour: hour.to_i, count: count } }
             .sort_by { |item| item[:hour] }
  end

  def top_ip_addresses(days_ago)
    SystemLog.where('created_at >= ?', days_ago.days.ago)
             .where.not(ip_address: nil)
             .group(:ip_address)
             .count
             .sort_by { |_, count| -count }
             .first(10)
             .map { |ip, count| { ip_address: ip, requests_count: count } }
  end

  def action_resource_matrix(days_ago)
    data = SystemLog.where('created_at >= ?', days_ago.days.ago)
                   .group(:action, :resource_type)
                   .count
    
    matrix = {}
    data.each do |(action, resource_type), count|
      matrix[action] ||= {}
      matrix[action][resource_type] = count
    end
    
    matrix
  end

  def generate_csv_export(logs)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << [
        'ID',
        'Дата и время',
        'Пользователь',
        'Email',
        'Действие',
        'Тип ресурса',
        'ID ресурса',
        'Название ресурса',
        'IP адрес',
        'User Agent',
        'Изменения'
      ]
      
      logs.find_each do |log|
        csv << [
          log.id,
          log.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          log.user&.full_name || 'Система',
          log.user&.email,
          log.action_description,
          log.resource_type,
          log.resource_id,
          log.resource_name,
          log.ip_address,
          log.user_agent,
          log.changes&.to_json
        ]
      end
    end
  end

  # Методы автокомплита
  def autocomplete_users(query)
    User.joins("LEFT JOIN system_logs ON system_logs.user_id = users.id")
        .where("users.email ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ?", 
               "%#{query}%", "%#{query}%", "%#{query}%")
        .group("users.id, users.email, users.first_name, users.last_name")
        .order("COUNT(system_logs.id) DESC")
        .limit(10)
        .pluck(:email)
  end

  def autocomplete_resource_types(query)
    SystemLog.where("resource_type ILIKE ?", "%#{query}%")
             .group(:resource_type)
             .order("COUNT(*) DESC")
             .limit(10)
             .pluck(:resource_type)
  end

  def autocomplete_actions(query)
    SystemLog.where("action ILIKE ?", "%#{query}%")
             .group(:action)
             .order("COUNT(*) DESC")
             .limit(10)
             .pluck(:action)
  end

  def autocomplete_ip_addresses(query)
    SystemLog.where("ip_address::text ILIKE ?", "%#{query}%")
             .where.not(ip_address: nil)
             .group(:ip_address)
             .order("COUNT(*) DESC")
             .limit(10)
             .pluck(:ip_address)
  end

  def autocomplete_resource_names(query)
    # Это более сложный запрос, так как resource_name - это виртуальное поле
    # Для простоты возвращаем пустой массив, можно расширить позже
    []
  end

  # Методы обнаружения подозрительной активности
  def detect_frequent_failed_logins(days_ago)
    # Ищем частые неудачные попытки входа (больше 10 за час)
    failed_attempts = SystemLog.where(action: 'login_failed')
                              .where('created_at >= ?', days_ago.days.ago)
                              .group(:ip_address, "DATE_TRUNC('hour', created_at)")
                              .having('COUNT(*) > 10')
                              .count

    failed_attempts.map do |(ip, hour), count|
      {
        ip_address: ip,
        hour: hour,
        failed_attempts: count,
        severity: count > 20 ? 'high' : 'medium'
      }
    end
  end

  def detect_multiple_ip_logins(days_ago)
    # Ищем пользователей с входами с более чем 5 разных IP за день
    multiple_ips = SystemLog.joins(:user)
                           .where(action: 'login')
                           .where('system_logs.created_at >= ?', days_ago.days.ago)
                           .group(:user_id, "DATE(system_logs.created_at)")
                           .having('COUNT(DISTINCT ip_address) > 5')
                           .includes(:user)

    multiple_ips.map do |log|
      ip_count = SystemLog.where(user: log.user, action: 'login')
                         .where('DATE(created_at) = ?', log.created_at.to_date)
                         .distinct.count(:ip_address)

      {
        user_id: log.user.id,
        user_email: log.user.email,
        date: log.created_at.to_date,
        unique_ips: ip_count,
        severity: ip_count > 10 ? 'high' : 'medium'
      }
    end
  end

  def detect_bulk_data_changes(days_ago)
    # Ищем пользователей с более чем 100 изменениями за час
    bulk_changes = SystemLog.joins(:user)
                           .where('created_at >= ?', days_ago.days.ago)
                           .where(action: ['created', 'updated', 'deleted'])
                           .group(:user_id, "DATE_TRUNC('hour', created_at)")
                           .having('COUNT(*) > 100')
                           .includes(:user)

    bulk_changes.map do |log|
      changes_count = SystemLog.where(user: log.user)
                              .where('created_at >= ? AND created_at < ?', 
                                     log.created_at.beginning_of_hour, 
                                     log.created_at.beginning_of_hour + 1.hour)
                              .count

      {
        user_id: log.user.id,
        user_email: log.user.email,
        hour: log.created_at.beginning_of_hour,
        changes_count: changes_count,
        severity: changes_count > 500 ? 'high' : 'medium'
      }
    end
  end

  def detect_suspicious_ips(days_ago)
    # Ищем IP с аномально высокой активностью
    suspicious_ips = SystemLog.where('created_at >= ?', days_ago.days.ago)
                             .where.not(ip_address: nil)
                             .group(:ip_address)
                             .having('COUNT(*) > 1000')
                             .count

    suspicious_ips.map do |ip, count|
      unique_users = SystemLog.where(ip_address: ip)
                             .where('created_at >= ?', days_ago.days.ago)
                             .distinct.count(:user_id)

      {
        ip_address: ip,
        total_requests: count,
        unique_users: unique_users,
        severity: count > 5000 ? 'high' : 'medium'
      }
    end
  end

  def detect_off_hours_activity(days_ago)
    # Ищем активность в нерабочее время (22:00-06:00, выходные)
    off_hours_logs = SystemLog.where('created_at >= ?', days_ago.days.ago)
                             .where(
                               "EXTRACT(hour FROM created_at) < 6 OR EXTRACT(hour FROM created_at) > 22 OR EXTRACT(dow FROM created_at) IN (0, 6)"
                             )
                             .joins(:user)
                             .group(:user_id)
                             .having('COUNT(*) > 50')
                             .includes(:user)

    off_hours_logs.map do |log|
      off_hours_count = SystemLog.where(user: log.user)
                                .where('created_at >= ?', days_ago.days.ago)
                                .where(
                                  "EXTRACT(hour FROM created_at) < 6 OR EXTRACT(hour FROM created_at) > 22 OR EXTRACT(dow FROM created_at) IN (0, 6)"
                                )
                                .count

      {
        user_id: log.user.id,
        user_email: log.user.email,
        off_hours_activity: off_hours_count,
        severity: off_hours_count > 200 ? 'high' : 'medium'
      }
    end
  end

  def detect_unusual_access_patterns(days_ago)
    # Ищем необычные паттерны доступа (например, доступ к ресурсам, к которым пользователь обычно не обращается)
    unusual_patterns = []

    # Пример: пользователи, которые внезапно начали работать с ресурсами, к которым раньше не обращались
    recent_resources = SystemLog.where('created_at >= ?', 7.days.ago)
                               .joins(:user)
                               .group(:user_id, :resource_type)
                               .having('COUNT(*) > 10')

    recent_resources.each do |log|
      historical_access = SystemLog.where(user: log.user, resource_type: log.resource_type)
                                  .where('created_at < ?', 7.days.ago)
                                  .count

      if historical_access == 0 # Новый тип ресурса для пользователя
        recent_count = SystemLog.where(user: log.user, resource_type: log.resource_type)
                               .where('created_at >= ?', 7.days.ago)
                               .count

        unusual_patterns << {
          user_id: log.user.id,
          user_email: log.user.email,
          resource_type: log.resource_type,
          recent_access_count: recent_count,
          pattern: 'new_resource_access',
          severity: recent_count > 50 ? 'high' : 'medium'
        }
      end
    end

    unusual_patterns
  end

  def serialize_timeline_event(log)
    {
      id: log.id,
      time: log.created_at.strftime('%H:%M:%S'),
      date: log.created_at.to_date.to_s,
      action: log.action_description,
      resource: log.resource_name || "#{log.resource_type} ##{log.resource_id}",
      ip_address: log.ip_address,
      details: {
        resource_type: log.resource_type,
        resource_id: log.resource_id,
        changes: log.changes
      }
    }
  end

  def get_resource_info(resource_type, resource_id)
    begin
      resource_class = resource_type.constantize
      resource = resource_class.find(resource_id)
      
      {
        type: resource_type,
        id: resource_id,
        name: resource.try(:name) || resource.try(:title) || resource.try(:full_name) || "#{resource_type} ##{resource_id}",
        status: resource.try(:is_active) || resource.try(:active) || 'unknown',
        exists: true
      }
    rescue => e
      {
        type: resource_type,
        id: resource_id,
        name: "#{resource_type} ##{resource_id} (удален)",
        status: 'deleted',
        exists: false,
        error: e.message
      }
    end
  end
end
