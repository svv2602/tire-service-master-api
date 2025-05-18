class Manager < ApplicationRecord
  # Связи
  belongs_to :user
  belongs_to :partner
  has_many :manager_service_points, dependent: :destroy
  has_many :service_points, through: :manager_service_points
  
  # Валидации
  validates :user_id, presence: true, uniqueness: true
  validates :partner_id, presence: true
  validates :position, presence: true
  validates :access_level, numericality: { only_integer: true, greater_than: 0 }
  
  # Константы
  READ_ONLY_ACCESS = 1
  FULL_ACCESS = 2
  
  # Методы
  def read_only?
    access_level == READ_ONLY_ACCESS
  end
  
  def full_access?
    access_level == FULL_ACCESS
  end
  
  def full_name
    user.full_name
  end
  
  def manages_service_point?(service_point)
    manager_service_points.exists?(service_point_id: service_point.id)
  end
  
  # Скоупы
  scope :active, -> { joins(:user).where(users: { is_active: true }) }
  scope :for_partner, ->(partner_id) { where(partner_id: partner_id) }
end
