class TelegramNotification < ApplicationRecord
  belongs_to :user
  belongs_to :booking, optional: true

  # Типы уведомлений
  enum :notification_type, { booking: 'booking', general: 'general', promotion: 'promotion', reminder: 'reminder', system: 'system' }

  # Статусы отправки
  enum :status, { pending: 'pending', sent: 'sent', failed: 'failed' }

  validates :message, presence: true
  validates :chat_id, presence: true
  validates :notification_type, presence: true
  validates :status, presence: true
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_chat, ->(chat_id) { where(chat_id: chat_id) }
  scope :by_type, ->(type) { where(notification_type: type) }

  before_validation :set_defaults

  def mark_as_sent!(response = {}, telegram_message_id = nil)
    update!(
      status: 'sent',
      sent_at: Time.current,
      telegram_response: response,
      message_id: telegram_message_id,
      error_message: nil
    )
  end

  def mark_as_failed!(error_msg)
    update!(
      status: 'failed',
      error_message: error_msg,
      retry_count: retry_count + 1
    )
  end

  def can_retry?
    failed? && retry_count < 3
  end

  def should_retry?
    can_retry? && 
    created_at > 24.hours.ago && 
    !error_message&.include?('chat not found')
  end

  def retry_notification!
    return false unless can_retry?
    
    telegram_service = TelegramService.new
    
    begin
      response = telegram_service.send_message(chat_id, message)
      
      if response[:ok]
        mark_as_sent!(response, response[:result][:message_id])
        true
      else
        mark_as_failed!(response[:description])
        false
      end
    rescue => e
      mark_as_failed!(e.message)
      false
    end
  end

  def formatted_created_at
    created_at.strftime('%d.%m.%Y %H:%M')
  end

  def status_icon
    case status
    when 'pending' then '⏳'
    when 'sent' then '✅'
    when 'failed' then '❌'
    end
  end

  def type_icon
    case notification_type
    when 'booking' then '📅'
    when 'general' then '📢'
    when 'promotion' then '🎉'
    when 'reminder' then '⏰'
    when 'system' then '⚙️'
    end
  end

  private

  def set_defaults
    self.status ||= 'pending'
    self.notification_type ||= 'general'
    self.retry_count ||= 0
  end
  end
