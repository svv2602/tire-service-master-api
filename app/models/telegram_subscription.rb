class TelegramSubscription < ApplicationRecord
  belongs_to :user
  has_many :telegram_notifications, dependent: :destroy

  # Статусы подписки
  enum :status, { active: 'active', blocked: 'blocked', inactive: 'inactive' }

  validates :chat_id, presence: true, uniqueness: true
  validates :status, presence: true
  validates :is_active, inclusion: { in: [true, false] }

  scope :active_subscriptions, -> { where(is_active: true, status: 'active') }
  scope :by_language, ->(lang) { where(language_code: lang) }

  before_validation :set_defaults

  def can_receive_notifications?
    is_active? && active?
  end

  def full_name
    [first_name, last_name].compact.join(' ')
  end

  def update_last_interaction!
    update!(last_interaction_at: Time.current)
  end

  def notification_preferences_hash
    return {} if notification_preferences.blank?
    
    begin
      JSON.parse(notification_preferences) 
    rescue JSON::ParserError
      {}
    end
  end

  def set_notification_preference(type, enabled)
    prefs = notification_preferences_hash
    prefs[type.to_s] = enabled
    update!(notification_preferences: prefs.to_json)
  end

  def notification_enabled?(type)
    prefs = notification_preferences_hash
    prefs.fetch(type.to_s, true) # по умолчанию включено
  end

  def sent_notifications_count
    telegram_notifications.sent.count
  end

  def success_rate
    total = telegram_notifications.count
    return 0 if total.zero?
    
    successful = telegram_notifications.sent.count
    (successful.to_f / total * 100).round(1)
  end

  private

  def set_defaults
    self.is_active = true if is_active.nil?
    self.status ||= 'active'
    self.language_code ||= 'ru'
  end
end 
