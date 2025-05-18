class Notification < ApplicationRecord
  # Связи
  belongs_to :notification_type
  
  # Валидации
  validates :recipient_type, presence: true
  validates :recipient_id, presence: true
  validates :title, presence: true
  validates :message, presence: true
  validates :send_via, presence: true, inclusion: { in: ['push', 'email', 'sms'] }
  
  # Скоупы
  scope :unread, -> { where(is_read: false) }
  scope :read, -> { where(is_read: true) }
  scope :sent, -> { where.not(sent_at: nil) }
  scope :unsent, -> { where(sent_at: nil) }
  scope :for_recipient, ->(type, id) { where(recipient_type: type, recipient_id: id) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Методы
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
end
