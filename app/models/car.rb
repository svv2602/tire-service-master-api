class Car < ApplicationRecord
  # Связи
  belongs_to :client
  belongs_to :car_type
  has_many :bookings, dependent: :restrict_with_error

  # Валидации
  validates :brand, presence: true
  validates :model, presence: true
  validates :license_plate, presence: true, uniqueness: { case_sensitive: false }
  validates :year, numericality: { only_integer: true, greater_than: 1900, less_than_or_equal_to: -> { Date.current.year + 1 } }, allow_nil: true
  validates :is_active, inclusion: { in: [true, false] }, allow_nil: true

  # Коллбэки
  before_save :normalize_license_plate
  before_validation :set_default_values

  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_brand, ->(brand) { where('LOWER(brand) = ?', brand.to_s.downcase) }
  scope :by_model, ->(model) { where('LOWER(model) = ?', model.to_s.downcase) }
  scope :by_year, ->(year) { where(year: year) }
  scope :search, ->(query) {
    where('LOWER(brand) LIKE ? OR LOWER(model) LIKE ? OR LOWER(license_plate) LIKE ?',
          "%#{query.to_s.downcase}%", "%#{query.to_s.downcase}%", "%#{query.to_s.downcase}%")
  }

  # Методы
  def full_name
    "#{brand} #{model} (#{year})"
  end

  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end

  private

  def normalize_license_plate
    self.license_plate = license_plate.upcase.gsub(/\s+/, '') if license_plate.present?
  end

  def set_default_values
    self.is_active = true if is_active.nil?
  end
end
