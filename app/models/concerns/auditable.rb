module Auditable
  extend ActiveSupport::Concern

  included do
    # Колбэки для автоматического логирования
    after_create :log_creation
    after_update :log_update
    after_destroy :log_deletion
    
    # Атрибут для передачи текущего пользователя
    attr_accessor :current_user_for_audit
    
    # Атрибут для отключения аудита (для массовых операций)
    attr_accessor :skip_audit
    
    # Атрибут для выбора синхронного или асинхронного логирования
    attr_accessor :async_audit
  end

  private

  def log_creation
    return if skip_audit || !should_audit?
    
    audit_data = {
      user_id: current_user_for_audit&.id,
      resource_type: self.class.name,
      resource_id: id,
      new_value: auditable_attributes,
      ip_address: current_ip_address,
      user_agent: current_user_agent,
      additional_data: audit_context_data
    }
    
    if use_async_audit?
      AuditLogJob.log_create(**audit_data)
    else
      SystemLog.log_create(
        current_user_for_audit,
        self.class.name,
        id,
        auditable_attributes,
        ip_address: current_ip_address,
        user_agent: current_user_agent
      )
    end
    
    # Проверяем на подозрительную активность
    check_for_suspicious_activity('created')
  end

  def log_update
    return if skip_audit || !should_audit? || !saved_changes.any?
    
    # Исключаем системные поля из логирования
    significant_changes = saved_changes.except('updated_at', 'created_at')
    return if significant_changes.empty?
    
    audit_data = {
      user_id: current_user_for_audit&.id,
      resource_type: self.class.name,
      resource_id: id,
      old_value: changes_before_save,
      new_value: auditable_attributes,
      changes: significant_changes,
      ip_address: current_ip_address,
      user_agent: current_user_agent,
      additional_data: audit_context_data
    }
    
    if use_async_audit?
      AuditLogJob.log_update(**audit_data)
    else
      SystemLog.log_update(
        current_user_for_audit,
        self.class.name,
        id,
        changes_before_save,
        auditable_attributes,
        significant_changes,
        ip_address: current_ip_address,
        user_agent: current_user_agent
      )
    end
    
    # Проверяем на подозрительную активность
    check_for_suspicious_activity('updated')
  end

  def log_deletion
    return if skip_audit || !should_audit?
    
    audit_data = {
      user_id: current_user_for_audit&.id,
      resource_type: self.class.name,
      resource_id: id,
      old_value: auditable_attributes,
      ip_address: current_ip_address,
      user_agent: current_user_agent,
      additional_data: audit_context_data
    }
    
    if use_async_audit?
      AuditLogJob.log_delete(**audit_data)
    else
      SystemLog.log_delete(
        current_user_for_audit,
        self.class.name,
        id,
        auditable_attributes,
        ip_address: current_ip_address,
        user_agent: current_user_agent
      )
    end
    
    # Проверяем на подозрительную активность
    check_for_suspicious_activity('deleted')
  end

  def should_audit?
    # Можно переопределить в конкретных моделях
    true
  end

  def auditable_attributes
    # Исключаем системные поля и пароли
    excluded_fields = %w[created_at updated_at password password_digest encrypted_password]
    attributes.except(*excluded_fields)
  end

  def changes_before_save
    # Получаем старые значения из изменений
    saved_changes.transform_values(&:first)
  end

  def current_ip_address
    # IP адрес можно получить из Thread.current если установлен в контроллере
    Thread.current[:current_ip_address]
  end

  def current_user_agent
    # User-Agent можно получить из Thread.current если установлен в контроллере
    Thread.current[:current_user_agent]
  end
  
  def use_async_audit?
    # Проверяем принудительное значение из Thread
    return Thread.current[:force_async_audit] if Thread.current[:force_async_audit] != nil
    
    # Используем асинхронное логирование по умолчанию, если не указано иное
    return async_audit if async_audit != nil
    
    # В production используем асинхронное логирование для улучшения производительности
    Rails.env.production? || Rails.application.config.respond_to?(:audit_async_default) && Rails.application.config.audit_async_default
  end
  
  def audit_context_data
    # Дополнительные данные для аудита, можно переопределить в моделях
    context = {}
    
    # Добавляем информацию о связанных объектах
    context[:related_objects] = related_audit_objects if respond_to?(:related_audit_objects, true)
    
    # Добавляем пользовательские данные
    context[:custom_data] = custom_audit_data if respond_to?(:custom_audit_data, true)
    
    # Добавляем информацию о сессии
    context[:session_id] = Thread.current[:current_session_id] if Thread.current[:current_session_id]
    
    # Добавляем информацию о запросе
    context[:request_id] = Thread.current[:current_request_id] if Thread.current[:current_request_id]
    
    context.empty? ? nil : context
  end

  class_methods do
    def with_audit_context(user: nil, ip_address: nil, user_agent: nil, session_id: nil, request_id: nil)
      old_user = Thread.current[:current_audit_user]
      old_ip = Thread.current[:current_ip_address]
      old_agent = Thread.current[:current_user_agent]
      old_session = Thread.current[:current_session_id]
      old_request = Thread.current[:current_request_id]
      
      Thread.current[:current_audit_user] = user
      Thread.current[:current_ip_address] = ip_address
      Thread.current[:current_user_agent] = user_agent
      Thread.current[:current_session_id] = session_id
      Thread.current[:current_request_id] = request_id
      
      yield
    ensure
      Thread.current[:current_audit_user] = old_user
      Thread.current[:current_ip_address] = old_ip
      Thread.current[:current_user_agent] = old_agent
      Thread.current[:current_session_id] = old_session
      Thread.current[:current_request_id] = old_request
    end
    
    def without_audit(&block)
      old_value = Thread.current[:skip_audit]
      Thread.current[:skip_audit] = true
      yield
    ensure
      Thread.current[:skip_audit] = old_value
    end
    
    def with_async_audit(async: true, &block)
      # Устанавливаем режим асинхронного аудита для всех операций в блоке
      old_async = Thread.current[:force_async_audit]
      Thread.current[:force_async_audit] = async
      yield
    ensure
      Thread.current[:force_async_audit] = old_async
    end
    
    def audit_critical_operation(user:, operation_type:, resource_type: nil, resource_id: nil, **context)
      # Специальный метод для логирования критичных операций
      AuditLogJob.perform_later(
        action: operation_type,
        user_id: user&.id,
        resource_type: resource_type,
        resource_id: resource_id,
        additional_data: {
          operation_type: operation_type,
          timestamp: Time.current,
          **context
        },
        ip_address: Thread.current[:current_ip_address],
        user_agent: Thread.current[:current_user_agent]
      )
    end

    # Проверка на подозрительную активность
    def check_for_suspicious_activity(action)
      return unless current_user_for_audit
      
      # Проверяем только в рабочее время для некритичных действий
      if is_off_hours? && is_critical_action?(action)
        SecurityAlertJob.perform_later(
          'off_hours_activity',
          user: current_user_for_audit,
          action: action,
          resource: "#{self.class.name}##{id}",
          timestamp: Time.current
        )
      end
      
      # Проверяем на массовые изменения (отложенная проверка)
      if %w[created updated deleted].include?(action)
        BulkActivityCheckJob.perform_later(current_user_for_audit.id, 1.hour.ago)
      end
    end

    def is_off_hours?
      current_hour = Time.current.hour
      # Нерабочее время: с 22:00 до 6:00 и выходные
      current_hour < 6 || current_hour > 22 || Time.current.weekend?
    end

    def is_critical_action?(action)
      %w[deleted suspended].include?(action.to_s) || 
      self.class.name.in?(%w[User SystemLog UserRole])
    end
  end
end 