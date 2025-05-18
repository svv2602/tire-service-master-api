class Weekday < ApplicationRecord
  # Связи
  has_many :schedule_templates, dependent: :destroy
  
  # Валидации
  validates :name, presence: true
  validates :short_name, presence: true
  validates :sort_order, presence: true
  
  # Скоупы
  scope :sorted, -> { order(sort_order: :asc) }
  
  # Методы
  def self.monday
    find_by(name: 'Monday')
  end
  
  def self.tuesday
    find_by(name: 'Tuesday')
  end
  
  def self.wednesday
    find_by(name: 'Wednesday')
  end
  
  def self.thursday
    find_by(name: 'Thursday')
  end
  
  def self.friday
    find_by(name: 'Friday')
  end
  
  def self.saturday
    find_by(name: 'Saturday')
  end
  
  def self.sunday
    find_by(name: 'Sunday')
  end
end
