class CarBrand < ApplicationRecord
  # Active Storage
  has_one_attached :logo

  # Связи
  has_many :car_models, foreign_key: 'brand_id', dependent: :destroy
  has_many :client_cars, foreign_key: 'brand_id', dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  validate :acceptable_logo
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :alphabetical, -> { order(:name) }

  # Методы
  def models_count
    car_models.count
  end

  def as_json(options = {})
    {
      'id' => id,
      'name' => name,
      'is_active' => is_active,
      'models_count' => models_count,
      'logo' => logo.attached? ? Rails.application.routes.url_helpers.rails_blob_path(logo, only_path: true) : nil
    }
  end

  private

  def acceptable_logo
    return unless logo.attached?

    unless logo.blob.byte_size <= 1.megabyte
      errors.add(:logo, 'слишком большой размер (не более 1MB)')
    end

    acceptable_types = ['image/jpeg', 'image/png']
    unless acceptable_types.include?(logo.content_type)
      errors.add(:logo, 'должен быть JPEG или PNG')
    end
  end
end
