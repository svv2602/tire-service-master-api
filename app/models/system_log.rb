class SystemLog < ApplicationRecord
  # Связи
  belongs_to :user, optional: true
  
  # Валидации
  validates :action, presence: true
  validates :resource_type, presence: true, if: -> { resource_id.present? }
  
  # Константы для типов действий
  ACTIONS = %w[created updated deleted suspended unsuspended assigned unassigned login logout].freeze
  
  # Константы для типов ресурсов
  RESOURCE_TYPES = %w[User Booking ServicePoint Operator Partner Client Manager Review].freeze
  
  # Скоупы
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_resource, ->(resource_type, resource_id = nil) { 
    resource_id.nil? ? where(resource_type: resource_type) : where(resource_type: resource_type, resource_id: resource_id)
  }
  scope :in_date_range, ->(from_date, to_date) { where(created_at: from_date..to_date) }
  scope :cleanup_old, ->(days_ago = 30) { where('created_at < ?', days_ago.days.ago) }
  
  # Методы для создания логов для разных действий
  def self.log_create(user, resource_type, resource_id, new_value, **options)
    create_log(
      user: user,
      action: 'created',
      resource_type: resource_type,
      resource_id: resource_id,
      new_value: new_value,
      **options
    )
  end
  
  def self.log_update(user, resource_type, resource_id, old_value, new_value, changes = nil, **options)
    create_log(
      user: user,
      action: 'updated',
      resource_type: resource_type,
      resource_id: resource_id,
      old_value: old_value,
      new_value: new_value,
      changes: changes,
      **options
    )
  end
  
  def self.log_delete(user, resource_type, resource_id, old_value, **options)
    create_log(
      user: user,
      action: 'deleted',
      resource_type: resource_type,
      resource_id: resource_id,
      old_value: old_value,
      **options
    )
  end
  
  def self.log_suspend(user, suspended_user, reason, until_date = nil, **options)
    create_log(
      user: user,
      action: 'suspended',
      resource_type: 'User',
      resource_id: suspended_user.id,
      changes: {
        reason: reason,
        until_date: until_date,
        suspended_at: Time.current
      },
      **options
    )
  end
  
  def self.log_unsuspend(user, unsuspended_user, **options)
    create_log(
      user: user,
      action: 'unsuspended',
      resource_type: 'User',
      resource_id: unsuspended_user.id,
      changes: {
        unsuspended_at: Time.current
      },
      **options
    )
  end
  
  def self.log_assign(user, operator, service_point, **options)
    create_log(
      user: user,
      action: 'assigned',
      resource_type: 'OperatorServicePoint',
      resource_id: nil,
      changes: {
        operator_id: operator.id,
        service_point_id: service_point.id,
        assigned_at: Time.current
      },
      additional_data: {
        operator_name: operator.user.full_name,
        service_point_name: service_point.name
      },
      **options
    )
  end
  
  def self.log_unassign(user, operator, service_point, **options)
    create_log(
      user: user,
      action: 'unassigned',
      resource_type: 'OperatorServicePoint',
      resource_id: nil,
      changes: {
        operator_id: operator.id,
        service_point_id: service_point.id,
        unassigned_at: Time.current
      },
      additional_data: {
        operator_name: operator.user.full_name,
        service_point_name: service_point.name
      },
      **options
    )
  end
  
  def self.log_login(user, **options)
    create_log(
      user: user,
      action: 'login',
      resource_type: 'User',
      resource_id: user.id,
      **options
    )
  end
  
  def self.log_logout(user, **options)
    create_log(
      user: user,
      action: 'logout',
      resource_type: 'User',
      resource_id: user.id,
      **options
    )
  end
  
  # Статистические методы
  def self.stats_by_action(days_ago = 30)
    where('created_at >= ?', days_ago.days.ago)
      .group(:action)
      .count
  end
  
  def self.stats_by_user(days_ago = 30)
    joins(:user)
      .where('system_logs.created_at >= ?', days_ago.days.ago)
      .group('users.email')
      .count
  end
  
  def self.most_active_resources(days_ago = 30, limit = 10)
    where('created_at >= ?', days_ago.days.ago)
      .where.not(resource_type: nil)
      .group(:resource_type)
      .count
      .sort_by { |_, count| -count }
      .first(limit)
  end
  
  # Методы экземпляра
  def resource_name
    return nil unless resource_type && resource_id
    
    begin
      resource_class = resource_type.constantize
      resource = resource_class.find(resource_id)
      
      case resource_type
      when 'User'
        resource.full_name
      when 'ServicePoint'
        resource.name
      when 'Booking'
        "Бронирование ##{resource.id}"
      else
        "#{resource_type} ##{resource_id}"
      end
    rescue => e
      "#{resource_type} ##{resource_id} (удален)"
    end
  end
  
  def action_description
    case action
    when 'created' then 'Создание'
    when 'updated' then 'Обновление'
    when 'deleted' then 'Удаление'
    when 'suspended' then 'Блокировка'
    when 'unsuspended' then 'Разблокировка'
    when 'assigned' then 'Назначение'
    when 'unassigned' then 'Отзыв назначения'
    when 'login' then 'Вход в систему'
    when 'logout' then 'Выход из системы'
    else action.humanize
    end
  end
  
  private
  
  def self.create_log(user:, action:, resource_type: nil, resource_id: nil, old_value: nil, new_value: nil, changes: nil, additional_data: nil, ip_address: nil, user_agent: nil)
    create(
      user: user,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      old_value: old_value,
      new_value: new_value,
      changes: changes,
      additional_data: additional_data,
      ip_address: ip_address,
      user_agent: user_agent
    )
  rescue => e
    Rails.logger.error "Ошибка создания системного лога: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
