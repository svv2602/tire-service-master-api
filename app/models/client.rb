class Client < ApplicationRecord
  # Связи
  belongs_to :user
  has_many :cars, class_name: 'ClientCar', dependent: :destroy
  has_many :bookings, dependent: :nullify
  has_many :reviews, dependent: :nullify
  has_many :favorite_points, class_name: 'ClientFavoritePoint', dependent: :destroy
  has_many :favorite_service_points, through: :favorite_points, source: :service_point
  
  # Валидации
  validates :user_id, presence: true, uniqueness: true
  validates :preferred_notification_method, inclusion: { in: ['push', 'email', 'sms'] }
  
  # Методы
  def primary_car
    cars.find_by(is_primary: true)
  end
  
  def total_bookings
    bookings.count
  end
  
  def completed_bookings
    bookings.joins(:status).where(booking_statuses: { name: 'completed' }).count
  end
  
  def average_rating_given
    reviews.average(:rating).to_f
  end
end
