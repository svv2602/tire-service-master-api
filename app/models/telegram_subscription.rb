class TelegramSubscription < ApplicationRecord
  belongs_to :user
  has_many :telegram_notifications, dependent: :destroy

  validates :chat_id, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :is_active, inclusion: { in: [true, false] }
  validates :language_code, presence: true, inclusion: { in: %w[ru uk en] }
  validates :status, presence: true

  scope :active, -> { where(is_active: true, status: :active) }
  scope :blocked, -> { where(status: :blocked) }
  scope :inactive, -> { where(is_active: false) }

  # Предпочтения уведомлений (JSON) - используем атрибут типа JSON

  # Статусы подписки  
  enum :status, { active: 'active', blocked: 'blocked', inactive: 'inactive' }

  before_validation :set_defaults

  def full_name
    [first_name, last_name].compact.join(' ')
  end

  def display_name
    full_name.present? ? full_name : username || "User #{user_id}"
  end

  def can_receive_notifications?
    is_active? && status == 'active'
  end

  def notification_enabled?(type)
    return true if notification_preferences.blank?
    notification_preferences.fetch(type.to_s, true)
  end

  def update_last_interaction!
    update(last_interaction_at: Time.current)
  end

  def block!
    update(status: 'blocked', is_active: false)
  end

  def unblock!
    update(status: 'active', is_active: true)
  end

  def deactivate!
    update(is_active: false, status: 'inactive')
  end

  def activate!
    update(is_active: true, status: 'active')
  end

  # Статистика уведомлений
  def notifications_count
    telegram_notifications.count
  end

  def sent_notifications_count
    telegram_notifications.where(status: 'sent').count
  end

  def failed_notifications_count
    telegram_notifications.where(status: 'failed').count
  end

  def success_rate
    total = notifications_count
    return 0 if total.zero?
    ((sent_notifications_count.to_f / total) * 100).round(2)
  end

  private

  def set_defaults
    self.language_code ||= 'ru'
    self.status ||= 'active'
    self.is_active = true if is_active.nil?
    self.notification_preferences ||= {}
  end
end 