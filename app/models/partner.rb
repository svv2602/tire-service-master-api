class Partner < ApplicationRecord
  # Связи
  belongs_to :user
  has_many :managers, dependent: :destroy
  has_many :service_points, dependent: :destroy
  has_many :price_lists, dependent: :destroy
  has_many :promotions, dependent: :destroy
  
  # Валидации
  validates :user_id, presence: true, uniqueness: true
  validates :company_name, presence: true
  
  # Скоупы
  scope :with_active_user, -> { joins(:user).where(users: { is_active: true }) }
  
  # Методы
  def total_clients_served
    service_points.sum(:total_clients_served)
  end
  
  def average_rating
    service_points_count = service_points.count
    return 0 if service_points_count.zero?
    
    service_points.sum(:average_rating) / service_points_count
  end
end
