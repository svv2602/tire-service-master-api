class SystemLog < ApplicationRecord
  # Связи
  belongs_to :user, optional: true
  
  # Валидации
  validates :action, presence: true
  
  # Скоупы
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_entity, ->(entity_type, entity_id = nil) { 
    entity_id.nil? ? where(entity_type: entity_type) : where(entity_type: entity_type, entity_id: entity_id)
  }
  
  # Методы для создания логов для разных действий
  def self.log_create(user, entity_type, entity_id, new_value, ip_address = nil, user_agent = nil)
    create(
      user: user,
      action: 'create',
      entity_type: entity_type,
      entity_id: entity_id,
      new_value: new_value,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end
  
  def self.log_update(user, entity_type, entity_id, old_value, new_value, ip_address = nil, user_agent = nil)
    create(
      user: user,
      action: 'update',
      entity_type: entity_type,
      entity_id: entity_id,
      old_value: old_value,
      new_value: new_value,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end
  
  def self.log_delete(user, entity_type, entity_id, old_value, ip_address = nil, user_agent = nil)
    create(
      user: user,
      action: 'delete',
      entity_type: entity_type,
      entity_id: entity_id,
      old_value: old_value,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end
  
  def self.log_login(user, ip_address = nil, user_agent = nil)
    create(
      user: user,
      action: 'login',
      entity_type: 'user',
      entity_id: user.id,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end
end
