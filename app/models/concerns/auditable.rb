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
  end

  private

  def log_creation
    return if skip_audit || !should_audit?
    
    SystemLog.log_create(
      current_user_for_audit,
      self.class.name,
      id,
      auditable_attributes,
      ip_address: current_ip_address,
      user_agent: current_user_agent
    )
  end

  def log_update
    return if skip_audit || !should_audit? || !saved_changes.any?
    
    # Исключаем системные поля из логирования
    significant_changes = saved_changes.except('updated_at', 'created_at')
    return if significant_changes.empty?
    
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

  def log_deletion
    return if skip_audit || !should_audit?
    
    SystemLog.log_delete(
      current_user_for_audit,
      self.class.name,
      id,
      auditable_attributes,
      ip_address: current_ip_address,
      user_agent: current_user_agent
    )
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

  class_methods do
    def with_audit_context(user: nil, ip_address: nil, user_agent: nil)
      old_user = Thread.current[:current_audit_user]
      old_ip = Thread.current[:current_ip_address]
      old_agent = Thread.current[:current_user_agent]
      
      Thread.current[:current_audit_user] = user
      Thread.current[:current_ip_address] = ip_address
      Thread.current[:current_user_agent] = user_agent
      
      yield
    ensure
      Thread.current[:current_audit_user] = old_user
      Thread.current[:current_ip_address] = old_ip
      Thread.current[:current_user_agent] = old_agent
    end
    
    def without_audit(&block)
      old_value = Thread.current[:skip_audit]
      Thread.current[:skip_audit] = true
      yield
    ensure
      Thread.current[:skip_audit] = old_value
    end
  end
end 