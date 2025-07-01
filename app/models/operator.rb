class Operator < ApplicationRecord
  belongs_to :user
  belongs_to :partner

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
  
  private
  
  # Валидация: нельзя активировать оператора, если партнер неактивен
  def partner_must_be_active_to_activate_operator
    if is_active? && partner.present? && !partner.is_active?
      errors.add(:is_active, 'нельзя активировать, так как партнер неактивен')
    end
  end
end
