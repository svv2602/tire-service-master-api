class ServicePointPhoto < ApplicationRecord
  # Связи
  belongs_to :service_point
  
  # Подключаем Active Storage
  has_one_attached :file
  
  # Валидации
  validates :file, presence: true
  validate :file_type_validation
  validate :file_size_validation
  validate :photos_count_validation, on: :create
  
  # Скоупы
  scope :main, -> { where(is_main: true) }
  scope :sorted, -> { order(sort_order: :asc, created_at: :desc) }

  private

  def file_type_validation
    return unless file.attached?

    unless file.content_type.in?(%w[image/jpeg image/png image/gif])
      errors.add(:file, 'должен быть изображением (JPEG, PNG или GIF)')
    end
  end

  def file_size_validation
    return unless file.attached?

    if file.byte_size > 5.megabytes
      errors.add(:file, 'размер файла не должен превышать 5MB')
    end
  end

  def photos_count_validation
    if service_point && service_point.photos.count >= 10
      errors.add(:base, 'превышено максимальное количество фотографий (10)')
    end
  end
end
