class NotificationType < ApplicationRecord
  # Связи
  has_many :notifications, dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :push_notifications, -> { where(is_push: true) }
  scope :email_notifications, -> { where(is_email: true) }
  scope :sms_notifications, -> { where(is_sms: true) }
end
