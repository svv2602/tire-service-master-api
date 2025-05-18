class ScheduleTemplate < ApplicationRecord
  # Связи
  belongs_to :service_point
  belongs_to :weekday
  
  # Валидации
  validates :opening_time, presence: true
  validates :closing_time, presence: true
  validates :service_point_id, uniqueness: { scope: :weekday_id }
  validate :closing_time_after_opening_time
  
  # Скоупы
  scope :working_days, -> { where(is_working_day: true) }
  scope :by_weekday_sort, -> { joins(:weekday).order('weekdays.sort_order') }
  
  # Методы
  def duration_in_minutes
    return 0 unless is_working_day
    
    minutes_opening = opening_time.hour * 60 + opening_time.min
    minutes_closing = closing_time.hour * 60 + closing_time.min
    minutes_closing - minutes_opening
  end
  
  private
  
  def closing_time_after_opening_time
    return unless opening_time && closing_time
    
    if closing_time <= opening_time
      errors.add(:closing_time, "must be after opening time")
    end
  end
end
