class Operator < ApplicationRecord
  # Связи
  belongs_to :user
  belongs_to :partner
  
  # Связи many-to-many с сервисными точками
  has_many :operator_service_points, dependent: :destroy
  has_many :service_points, through: :operator_service_points
  has_many :active_service_points, -> { where(operator_service_points: { is_active: true }) }, 
           through: :operator_service_points, source: :service_point

  # Валидации
  validates :position, presence: true
  validates :access_level, presence: true, inclusion: { in: 1..5 }
  validates :is_active, inclusion: { in: [true, false] }
  
  # Валидация: нельзя активировать оператора, если партнер неактивен
  validate :partner_must_be_active_to_activate_operator

  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_access_level, ->(level) { where(access_level: level) }
  scope :assigned_to_service_point, ->(service_point_id) { 
    joins(:operator_service_points)
      .where(operator_service_points: { service_point_id: service_point_id, is_active: true }) 
  }

  # Методы
  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end

  # Проверка уровня доступа
  def can_access?(required_level)
    access_level >= required_level
  end
  
  # Методы для работы с привязками к точкам
  def assign_to_service_point!(service_point)
    operator_service_points.find_or_create_by!(service_point: service_point) do |assignment|
      assignment.assigned_at = Time.current
      assignment.is_active = true
    end
  end

  def unassign_from_service_point!(service_point)
    assignment = operator_service_points.find_by(service_point: service_point)
    assignment&.deactivate!
  end

  def assigned_to_service_point?(service_point)
    operator_service_points.active.exists?(service_point: service_point)
  end

  def assigned_service_points_count
    operator_service_points.active.count
  end
  
  private
  
  # Валидация: нельзя активировать оператора, если партнер неактивен
  def partner_must_be_active_to_activate_operator
    if is_active? && partner.present? && !partner.is_active?
      errors.add(:is_active, 'нельзя активировать, так как партнер неактивен')
    end
  end
end
