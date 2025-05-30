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
  def as_json(options = {})
    super(options).tap do |json|
      if logo.attached?
        json['logo'] = Rails.application.routes.url_helpers.rails_blob_path(logo, only_path: true)
      end
    end
  end

  private

  def acceptable_logo
    return unless logo.attached?

    unless logo.blob.byte_size <= 5.megabyte
      errors.add(:logo, 'размер не должен превышать 5MB')
    end

    acceptable_types = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
    unless acceptable_types.include?(logo.content_type)
      errors.add(:logo, 'должен быть в формате JPEG, PNG, GIF или WebP')
    end
  end
end
