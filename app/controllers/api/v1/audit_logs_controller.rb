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
end
