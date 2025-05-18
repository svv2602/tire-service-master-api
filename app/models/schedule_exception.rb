class ScheduleException < ApplicationRecord
  # Связи
  belongs_to :service_point
  
  # Валидации
  validates :exception_date, presence: true
  validates :service_point_id, uniqueness: { scope: :exception_date }
  validate :validate_times_if_not_closed
  
  # Скоупы
  scope :upcoming, -> { where('exception_date >= ?', Date.current) }
  scope :past, -> { where('exception_date < ?', Date.current) }
  
  private
  
  def validate_times_if_not_closed
    return if is_closed
    
    if opening_time.blank? || closing_time.blank?
      errors.add(:base, "Opening and closing times are required when the service point is not closed")
    elsif closing_time <= opening_time
      errors.add(:closing_time, "must be after opening time")
    end
  end
end
