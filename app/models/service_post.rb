# Модель для индивидуальных постов обслуживания с настройками времени
class ServicePost < ApplicationRecord
  belongs_to :service_point
  
  # Валидации
  validates :post_number, presence: true, 
            uniqueness: { scope: :service_point_id, 
                         message: "Номер поста должен быть уникальным в рамках точки обслуживания" }
  validates :post_number, numericality: { greater_than: 0, 
                                         message: "Номер поста должен быть положительным числом" }
  validates :name, presence: true, length: { maximum: 255 }
  validates :slot_duration, presence: true, 
            numericality: { greater_than: 15, less_than_or_equal_to: 480,
                           message: "Длительность слота должна быть от 15 минут до 8 часов" }
  
  # Скоупы для удобного поиска
  scope :active, -> { where(is_active: true) }
  scope :for_service_point, ->(service_point_id) { where(service_point: service_point_id) }
  scope :ordered_by_post_number, -> { order(:post_number) }
  
  # Метод для получения длительности в секундах
  def slot_duration_in_seconds
    slot_duration * 60
  end
  
  # Метод для форматированного отображения поста
  def display_name
    "Пост #{post_number}#{name.present? ? " - #{name}" : ""}"
  end
  
  # Проверка доступности поста
  def available?
    is_active?
  end
  
  # Метод для получения следующего доступного времени
  def next_available_slot_start_time(from_time = Time.current)
    # Логика будет реализована позже в ScheduleManager
    from_time
  end
end
