class OperatorServicePoint < ApplicationRecord
  # Связи
  belongs_to :operator
  belongs_to :service_point

  # Валидации
  validates :operator_id, presence: true
  validates :service_point_id, presence: true
  validates :assigned_at, presence: true
  validates :is_active, inclusion: { in: [true, false] }
  
  # Кастомная валидация: оператор может быть привязан только к точкам своего партнера
  validate :operator_and_service_point_belong_to_same_partner
  
  # Валидация: нельзя создать дубликат активной привязки
  validates :operator_id, uniqueness: { 
    scope: :service_point_id, 
    message: 'уже привязан к этой сервисной точке' 
  }

  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :for_operator, ->(operator_id) { where(operator_id: operator_id) }
  scope :for_service_point, ->(service_point_id) { where(service_point_id: service_point_id) }
  scope :for_partner, ->(partner_id) { 
    joins(service_point: :partner).where(service_points: { partner_id: partner_id }) 
  }

  # Методы
  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end

  def partner
    service_point&.partner
  end

  private

  # Валидация принадлежности оператора и точки одному партнеру
  def operator_and_service_point_belong_to_same_partner
    return unless operator&.partner && service_point&.partner
    
    if operator.partner_id != service_point.partner_id
      errors.add(:service_point_id, 'должна принадлежать тому же партнеру, что и оператор')
    end
  end
end 