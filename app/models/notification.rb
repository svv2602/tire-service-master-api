class Notification < ApplicationRecord
  # Связи
  belongs_to :notification_type

  # Skip broadcasts flag for tests
  attr_accessor :skip_broadcasts

  # WebSocket broadcasting
  after_commit :broadcast_new_notification, on: :create, unless: -> { skip_broadcasts }
  after_commit :broadcast_read_status, on: :update, if: -> { saved_change_to_is_read? && !skip_broadcasts }
  
  # Енумы для новых полей (синтаксис для Rails 8)
  enum :priority, {
    low: 'low',
    normal: 'normal', 
    high: 'high',
    urgent: 'urgent'
  }
  
  enum :category, {
    general: 'general',
    booking: 'booking',
    system: 'system',
    promotion: 'promotion',
    reminder: 'reminder',
    security: 'security'
  }
  
  # Валидации
  validates :recipient_type, presence: true
  validates :recipient_id, presence: true
  validates :title, presence: true
  validates :message, presence: true
  validates :send_via, presence: true, inclusion: { in: ['push', 'email', 'sms', 'telegram'] }
  validates :priority, presence: true
  validates :category, presence: true
  
  # Скоупы для статуса
  scope :unread, -> { where(is_read: false) }
  scope :read, -> { where(is_read: true) }
  scope :sent, -> { where.not(sent_at: nil) }
  scope :unsent, -> { where(sent_at: nil) }
  
  # Скоупы для получателей
  scope :for_recipient, ->(type, id) { where(recipient_type: type, recipient_id: id) }
  scope :for_users, -> { where(recipient_type: 'User') }
  scope :for_clients, -> { where(recipient_type: 'Client') }
  scope :for_partners, -> { where(recipient_type: 'Partner') }
  
  # Скоупы для сортировки
  scope :recent, -> { order(created_at: :desc) }
  scope :by_priority, -> { order(:priority, created_at: :desc) }
  scope :urgent_first, -> { order(Arel.sql("CASE WHEN priority = 'urgent' THEN 0 WHEN priority = 'high' THEN 1 WHEN priority = 'normal' THEN 2 ELSE 3 END"), created_at: :desc) }
  
  # Скоупы для фильтрации
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :by_priority, ->(pri) { where(priority: pri) if pri.present? }
  scope :created_today, -> { where(created_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :created_this_week, -> { where(created_at: 1.week.ago..Time.current) }
  
  # Методы для управления статусом
  def mark_as_read!
    update(is_read: true, read_at: Time.current)
  end
  
  def mark_as_sent!
    update(sent_at: Time.current)
  end
  
  def read?
    is_read
  end
  
  def sent?
    sent_at.present?
  end
  
  # Методы для проверки приоритета
  def urgent?
    priority == 'urgent'
  end
  
  def high_priority?
    priority == 'high'
  end
  
  def low_priority?
    priority == 'low'
  end
  
  # Методы для категорий
  def booking_related?
    category == 'booking'
  end
  
  def system_notification?
    category == 'system'
  end
  
  def promotion?
    category == 'promotion'
  end
  
  # Статический метод для статистики
  def self.stats_for_recipient(recipient_type, recipient_id)
    notifications = for_recipient(recipient_type, recipient_id)
    {
      total: notifications.count,
      unread: notifications.unread.count,
      read: notifications.read.count,
      sent: notifications.sent.count,
      urgent: notifications.where(priority: 'urgent').count,
      by_category: notifications.group(:category).count,
      by_priority: notifications.group(:priority).count
    }
  end

  private

  def broadcast_new_notification
    return unless recipient_type == 'User' && recipient_id.present?

    user = User.find_by(id: recipient_id)
    return unless user

    NotificationsChannel.broadcast_notification(user, self)
  end

  def broadcast_read_status
    return unless recipient_type == 'User' && recipient_id.present? && is_read

    user = User.find_by(id: recipient_id)
    return unless user

    NotificationsChannel.broadcast_notification_read(user, id)
  end
end
