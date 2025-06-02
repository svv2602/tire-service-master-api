class ScheduleSlot < ApplicationRecord
  # Связи
  belongs_to :service_point
  belongs_to :service_post
  # has_many :bookings, foreign_key: 'slot_id', dependent: :restrict_with_error # УДАЛЕНО: в динамической системе бронирования не связаны со слотами
  
  # Валидации
  validates :slot_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :post_number, presence: true, numericality: { greater_than: 0 }
  validates :service_point_id, uniqueness: { scope: [:slot_date, :start_time, :post_number] }
  validate :end_time_after_start_time
  validate :service_post_belongs_to_service_point
  
  # Скоупы
  scope :available, -> { where(is_available: true) }
  scope :upcoming, -> { where('slot_date >= ?', Date.current) }
  scope :today, -> { where(slot_date: Date.current) }
  scope :future, -> { where('slot_date > ?', Date.current) }
  scope :by_date_range, ->(start_date, end_date) { 
    where('slot_date >= ? AND slot_date <= ?', start_date, end_date) 
  }
  scope :for_time_range, ->(start_time, end_time) {
    where('start_time >= ? AND end_time <= ?', start_time, end_time)
  }
  scope :for_service_post, ->(service_post_id) { where(service_post_id: service_post_id) }
  
  # Методы
  def duration_in_minutes
    minutes_start = start_time.hour * 60 + start_time.min
    minutes_end = end_time.hour * 60 + end_time.min
    minutes_end - minutes_start
  end
  
  # Проверка занятости теперь не актуальна, но оставляем для совместимости со старым кодом
  def booked?
    false # В динамической системе слоты не бронируются напрямую
  end
  
  # Получает длительность слота из настроек поста
  def configured_duration_in_minutes
    service_post&.slot_duration || duration_in_minutes
  end
  
  private
  
  def end_time_after_start_time
    return unless start_time && end_time
    
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
  
  def service_post_belongs_to_service_point
    return unless service_post && service_point
    
    if service_post.service_point_id != service_point_id
      errors.add(:service_post, "must belong to the same service point")
    end
  end
end
