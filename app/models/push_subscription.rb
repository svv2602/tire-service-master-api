class PushSubscription < ApplicationRecord
  belongs_to :user
  
  # Валидации
  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Методы для управления подпиской
  def activate!
    update!(is_active: true)
  end
  
  def deactivate!
    update!(is_active: false)
  end
  
  def update_last_interaction!
    touch(:last_used_at)
  end
  
  def increment_sent!
    increment!(:notifications_sent)
    update_last_interaction!
  end
  
  def increment_failed!
    increment!(:notifications_failed)
  end
  
  # Статистика
  def success_rate
    return 0 if notifications_sent == 0
    ((notifications_sent.to_f / (notifications_sent + notifications_failed)) * 100).round(2)
  end
  
  def total_notifications
    notifications_sent + notifications_failed
  end
  
  # Проверка активности
  def stale?
    last_used_at.nil? || last_used_at < 30.days.ago
  end
  
  def can_receive_notifications?
    is_active? && !stale?
  end
  
  # Информация о браузере
  def browser_info
    return 'Unknown' if user_agent.blank?
    
    case user_agent
    when /Chrome/
      'Chrome'
    when /Firefox/
      'Firefox'
    when /Safari/
      'Safari'
    when /Edge/
      'Edge'
    else
      'Other'
    end
  end
  
  # Методы для отображения
  def display_endpoint
    return 'N/A' if endpoint.blank?
    
    uri = URI.parse(endpoint)
    "#{uri.host}#{uri.path[0..20]}..."
  rescue
    endpoint[0..50] + '...'
  end
  
  def status_text
    if is_active?
      stale? ? 'Застаріла' : 'Активна'
    else
      'Неактивна'
    end
  end
end
