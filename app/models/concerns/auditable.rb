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
    
    # Check for suspicious activity
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
      record_changes: significant_changes,
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
    
    # Check for suspicious activity
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
    
    # Check for suspicious activity
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
    # IP address from CurrentContext (set by AuditContextMiddleware)
    CurrentContext.ip_address
  end

  def current_user_agent
    # User-Agent from CurrentContext (set by AuditContextMiddleware)
    CurrentContext.user_agent
  end

  def use_async_audit?
    # Check forced value from CurrentContext
    return CurrentContext.force_async_audit if CurrentContext.force_async_audit != nil

    # Use async logging by default unless explicitly set
    return async_audit if async_audit != nil

    # In production use async logging for better performance
    Rails.env.production? || Rails.application.config.respond_to?(:audit_async_default) && Rails.application.config.audit_async_default
  end

  def audit_context_data
    # Additional data for audit, can be overridden in models
    context = {}

    # Add related object information
    context[:related_objects] = related_audit_objects if respond_to?(:related_audit_objects, true)

    # Add custom data
    context[:custom_data] = custom_audit_data if respond_to?(:custom_audit_data, true)

    # Add session information
    context[:session_id] = CurrentContext.session_id if CurrentContext.session_id

    # Add request information
    context[:request_id] = CurrentContext.request_id if CurrentContext.request_id

    context.empty? ? nil : context
  end

  class_methods do
    def with_audit_context(user: nil, ip_address: nil, user_agent: nil, session_id: nil, request_id: nil)
      old_user = CurrentContext.audit_user
      old_ip = CurrentContext.ip_address
      old_agent = CurrentContext.user_agent
      old_session = CurrentContext.session_id
      old_request = CurrentContext.request_id

      CurrentContext.audit_user = user
      CurrentContext.ip_address = ip_address
      CurrentContext.user_agent = user_agent
      CurrentContext.session_id = session_id
      CurrentContext.request_id = request_id

      yield
    ensure
      CurrentContext.audit_user = old_user
      CurrentContext.ip_address = old_ip
      CurrentContext.user_agent = old_agent
      CurrentContext.session_id = old_session
      CurrentContext.request_id = old_request
    end

    def without_audit(&block)
      old_value = CurrentContext.skip_audit
      CurrentContext.skip_audit = true
      yield
    ensure
      CurrentContext.skip_audit = old_value
    end

    def with_async_audit(async: true, &block)
      # Set async audit mode for all operations within the block
      old_async = CurrentContext.force_async_audit
      CurrentContext.force_async_audit = async
      yield
    ensure
      CurrentContext.force_async_audit = old_async
    end

    def audit_critical_operation(user:, operation_type:, resource_type: nil, resource_id: nil, **context)
      # Special method for logging critical operations
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
        ip_address: CurrentContext.ip_address,
        user_agent: CurrentContext.user_agent
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