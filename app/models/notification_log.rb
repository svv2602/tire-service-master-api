class NotificationLog < ApplicationRecord
  # Связи
  belongs_to :template, class_name: 'EmailTemplate', foreign_key: 'template_id', optional: true
  belongs_to :recipient, polymorphic: true, optional: true
  
  # Валидации
  validates :notification_type, presence: true
  validates :recipient_type, presence: true
  validates :status, presence: true, inclusion: { 
    in: %w[pending sent delivered failed bounced opened clicked unsubscribed] 
  }
  validates :sent_at, presence: true, if: -> { status != 'pending' }
  
  # Скоупы
  scope :sent, -> { where(status: %w[sent delivered opened clicked]) }
  scope :failed, -> { where(status: %w[failed bounced]) }
  scope :delivered, -> { where(status: %w[delivered opened clicked]) }
  scope :opened, -> { where(status: %w[opened clicked]) }
  scope :clicked, -> { where(status: 'clicked') }
  
  scope :email_notifications, -> { where(notification_type: 'email') }
  scope :telegram_notifications, -> { where(notification_type: 'telegram') }
  
  scope :today, -> { where(sent_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(sent_at: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :this_month, -> { where(sent_at: Date.current.beginning_of_month..Date.current.end_of_month) }
  
  scope :by_template_type, ->(type) { where(template_type: type) }
  scope :by_recipient_type, ->(type) { where(recipient_type: type) }
  
  # Enum для статусов
  enum :status, {
    pending: 'pending',           # В очереди на отправку
    sent: 'sent',                 # Отправлено
    delivered: 'delivered',       # Доставлено
    failed: 'failed',             # Ошибка отправки
    bounced: 'bounced',           # Отклонено получателем
    opened: 'opened',             # Открыто получателем
    clicked: 'clicked',           # Клик по ссылке
    unsubscribed: 'unsubscribed'  # Отписка
  }
  
  # Методы для статистики
  def self.success_rate
    return 0 if count.zero?
    (delivered.count.to_f / count * 100).round(2)
  end
  
  def self.open_rate
    return 0 if delivered.count.zero?
    (opened.count.to_f / delivered.count * 100).round(2)
  end
  
  def self.click_rate
    return 0 if delivered.count.zero?
    (clicked.count.to_f / delivered.count * 100).round(2)
  end
  
  def self.bounce_rate
    return 0 if count.zero?
    (failed.count.to_f / count * 100).round(2)
  end
  
  # Статистика по типам
  def self.stats_by_type
    group(:template_type).group(:status).count
  end
  
  def self.stats_by_day(days = 7)
    where(sent_at: days.days.ago..Time.current)
      .group("DATE(sent_at)")
      .group(:status)
      .count
  end
  
  def self.stats_by_hour(hours = 24)
    where(sent_at: hours.hours.ago..Time.current)
      .group("DATE_TRUNC('hour', sent_at)")
      .group(:status)
      .count
  end
  
  # Методы для обновления статуса
  def mark_as_sent!
    update!(status: 'sent', sent_at: Time.current)
  end
  
  def mark_as_delivered!
    update!(status: 'delivered', delivered_at: Time.current)
  end
  
  def mark_as_failed!(error_msg = nil)
    update!(
      status: 'failed', 
      error_message: error_msg,
      sent_at: Time.current
    )
  end
  
  def mark_as_opened!
    update!(status: 'opened', opened_at: Time.current) unless opened_at.present?
  end
  
  def mark_as_clicked!
    update!(status: 'clicked', clicked_at: Time.current)
    mark_as_opened! unless opened_at.present?
  end
  
  # Методы для получения данных
  def response_time
    return nil unless sent_at && delivered_at
    delivered_at - sent_at
  end
  
  def time_to_open
    return nil unless delivered_at && opened_at
    opened_at - delivered_at
  end
  
  def time_to_click
    return nil unless opened_at && clicked_at
    clicked_at - opened_at
  end
  
  # Сериализация метаданных
  def metadata
    JSON.parse(self[:metadata] || '{}')
  rescue JSON::ParserError
    {}
  end
  
  def metadata=(value)
    self[:metadata] = value.to_json
  end
  
  def add_metadata(key, value)
    current_metadata = metadata
    current_metadata[key.to_s] = value
    self.metadata = current_metadata
    save!
  end
  
  # Текстовое представление статуса
  def status_text
    case status
    when 'pending' then 'В очереди'
    when 'sent' then 'Отправлено'
    when 'delivered' then 'Доставлено'
    when 'failed' then 'Ошибка'
    when 'bounced' then 'Отклонено'
    when 'opened' then 'Открыто'
    when 'clicked' then 'Переход по ссылке'
    when 'unsubscribed' then 'Отписка'
    else status.humanize
    end
  end
  
  # Цвет статуса для UI
  def status_color
    case status
    when 'pending' then 'yellow'
    when 'sent' then 'blue'
    when 'delivered' then 'green'
    when 'failed', 'bounced' then 'red'
    when 'opened' then 'purple'
    when 'clicked' then 'indigo'
    when 'unsubscribed' then 'gray'
    else 'gray'
    end
  end
end
