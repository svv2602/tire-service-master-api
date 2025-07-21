class Review < ApplicationRecord
  # Связи
  belongs_to :booking, optional: true
  belongs_to :client
  belongs_to :service_point
  
  # Валидации
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :booking_id, uniqueness: true, allow_nil: true
  validates :status, presence: true, inclusion: { in: %w[pending published rejected] }
  
  # Скоупы
  scope :published, -> { where(status: 'published') }
  scope :pending, -> { where(status: 'pending') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :ordered_by_date, -> { order(created_at: :desc) }
  
  # Колбэки для синхронизации is_published с status
  before_save :sync_is_published_with_status
  
  # Колбэки для обновления рейтинга сервисной точки
  after_save :update_service_point_rating
  after_destroy :update_service_point_rating
  
  # Колбэки для уведомлений
  after_create :send_review_creation_notification, unless: -> { skip_notifications }
  after_update :send_review_status_change_notification, if: -> { saved_change_to_status? && !skip_notifications }
  
  # Флаг для отключения уведомлений (для тестов и массовых операций)
  attr_accessor :skip_notifications
  
  private
  
  def sync_is_published_with_status
    self.is_published = (status == 'published')
  end
  
  def update_service_point_rating
    service_point.recalculate_metrics!
  end
  
  # Уведомление о создании нового отзыва
  def send_review_creation_notification
    # Email уведомление администраторам
    BookingNotificationJob.perform_later(id, 'admin_new_review', 'admin@test.com')
    
    # Telegram уведомление администраторам
    BookingNotificationJob.perform_later(id, 'telegram_admin_new_review')
    
    Rails.logger.info "📝 Отправлены уведомления о новом отзыве ID: #{id}"
  end
  
  # Уведомление об изменении статуса отзыва
  def send_review_status_change_notification
    case status
    when 'published'
      # Уведомляем клиента о публикации отзыва
      if client&.email.present?
        BookingNotificationJob.perform_later(id, 'review_published', client.email)
      end
      # Telegram уведомление клиенту
      BookingNotificationJob.perform_later(id, 'telegram_review_published')
      
    when 'rejected'
      # Уведомляем клиента об отклонении отзыва
      if client&.email.present?
        BookingNotificationJob.perform_later(id, 'review_rejected', client.email)
      end
      # Telegram уведомление клиенту
      BookingNotificationJob.perform_later(id, 'telegram_review_rejected')
    end
    
    Rails.logger.info "📝 Отправлены уведомления об изменении статуса отзыва ID: #{id} на #{status}"
  end
end
