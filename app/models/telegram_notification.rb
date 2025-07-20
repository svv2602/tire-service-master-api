class TelegramNotification < ApplicationRecord
  belongs_to :user
  belongs_to :booking, optional: true
  belongs_to :telegram_subscription, foreign_key: :chat_id, primary_key: :chat_id, optional: true

  validates :message, presence: true
  validates :chat_id, presence: true
  validates :notification_type, presence: true, inclusion: { 
    in: %w[booking general promotion reminder system] 
  }
  validates :status, presence: true, inclusion: { 
    in: %w[pending sent failed] 
  }
  validates :retry_count, presence: true, numericality: { 
    greater_than_or_equal_to: 0, less_than_or_equal_to: 5 
  }

  scope :sent, -> { where(status: 'sent') }
  scope :failed, -> { where(status: 'failed') }
  scope :pending, -> { where(status: 'pending') }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  # Сериализация JSON данных
  # serialize :telegram_response, JSON

  # Типы уведомлений
  enum :notification_type, { booking: 'booking', general: 'general', promotion: 'promotion', reminder: 'reminder', system: 'system' }

  # Статусы отправки
  enum :status, { pending: 'pending', sent: 'sent', failed: 'failed' }

  before_validation :set_defaults

  def mark_as_sent!(telegram_response = nil, message_id = nil)
    update!(
      status: 'sent',
      sent_at: Time.current,
      telegram_response: telegram_response,
      message_id: message_id
    )
  end

  def mark_as_failed!(error_message)
    update!(
      status: 'failed',
      error_message: error_message,
      retry_count: retry_count + 1
    )
  end

  def can_retry?
    status == 'failed' && retry_count < 5
  end

  def retry!
    return false unless can_retry?
    update!(status: 'pending', error_message: nil)
    true
  end

  def formatted_message
    case notification_type
    when 'booking'
      format_booking_message
    when 'system'
      format_system_message
    when 'promotion'
      format_promotion_message
    else
      message
    end
  end

  def delivery_time
    sent_at - created_at if sent_at.present?
  end

  def telegram_url
    return nil unless message_id.present?
    "https://t.me/c/#{chat_id}/#{message_id}"
  end

  # Статистические методы
  def self.success_rate
    total = count
    return 0 if total.zero?
    (sent.count.to_f / total * 100).round(2)
  end

  def self.average_delivery_time
    sent_notifications = sent.where.not(sent_at: nil)
    return 0 if sent_notifications.empty?
    
    total_time = sent_notifications.sum { |n| n.delivery_time || 0 }
    (total_time / sent_notifications.count).round(2)
  end

  def self.stats_by_type
    group(:notification_type).group(:status).count
  end

  private

  def set_defaults
    self.notification_type ||= 'general'
    self.status ||= 'pending'
    self.retry_count ||= 0
  end

  def format_booking_message
    return message unless booking.present?
    
    "🚗 #{message}\n\n" \
    "📅 Дата: #{booking.start_time.strftime('%d.%m.%Y')}\n" \
    "🕐 Время: #{booking.start_time.strftime('%H:%M')}\n" \
    "🏢 Сервис: #{booking.service_point&.name}\n" \
    "📱 Телефон: #{booking.service_point&.phone}"
  end

  def format_system_message
    "🔔 #{message}"
  end

  def format_promotion_message
    "🎉 #{message}"
  end
end 