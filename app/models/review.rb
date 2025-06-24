class Review < ApplicationRecord
  # Связи
  belongs_to :booking, optional: true
  belongs_to :client
  belongs_to :service_point
  
  # Валидации
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :booking_id, uniqueness: true, allow_nil: true
  
  # Скоупы
  scope :published, -> { where(is_published: true) }
  scope :ordered_by_date, -> { order(created_at: :desc) }
  
  # Колбэки для обновления рейтинга сервисной точки
  after_save :update_service_point_rating
  after_destroy :update_service_point_rating
  
  private
  
  def update_service_point_rating
    service_point.recalculate_metrics!
  end
end
