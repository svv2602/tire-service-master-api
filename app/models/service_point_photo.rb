class ServicePointPhoto < ApplicationRecord
  # Связи
  belongs_to :service_point
  
  # Подключаем Active Storage
  has_one_attached :file
  
  # Валидации
  validates :file, presence: true
  validates :description, length: { maximum: 1000 }
  validate :file_type_validation
  validate :file_size_validation
  validate :photos_count_validation, on: :create
  validate :only_one_main_photo
  
  # Скоупы
  scope :main, -> { where(is_main: true) }
  scope :sorted, -> { order(sort_order: :asc, created_at: :desc) }
  
  # Коллбэки
  before_save :ensure_only_one_main_photo

  private

  def file_type_validation
    return unless file.attached?

    unless file.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
      errors.add(:file, 'должен быть изображением (JPEG, PNG, GIF или WebP)')
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
  
  def only_one_main_photo
    return unless is_main
    
    main_photos = service_point.photos.where(is_main: true)
    main_photos = main_photos.where.not(id: id) if persisted?
    
    if main_photos.exists?
      errors.add(:is_main, 'может быть только одна главная фотография')
    end
  end
  
  def ensure_only_one_main_photo
    if is_main && is_main_changed?
      # Убираем флаг главной фотографии у всех остальных фотографий
      service_point.photos.where.not(id: id).update_all(is_main: false)
    end
  end
end
