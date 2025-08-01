class SupplierPriceVersion < ApplicationRecord
  # Связи
  belongs_to :supplier
  
  # Валидации
  validates :version, presence: true, length: { maximum: 100 }
  validates :version, uniqueness: { scope: :supplier_id }
  validates :products_count, numericality: { greater_than_or_equal_to: 0 }
  validates :processed_count, numericality: { greater_than_or_equal_to: 0 }
  validates :errors_count, numericality: { greater_than_or_equal_to: 0 }
  
  # Скоупы
  scope :recent, -> { order(uploaded_at: :desc) }
  scope :successful, -> { where('errors_count < products_count / 2') } # менее 50% ошибок
  
  # Колбэки
  before_validation :generate_version, on: :create, if: -> { version.blank? }
  
  # Методы
  def success_rate
    return 0 if products_count.zero?
    ((processed_count.to_f / products_count) * 100).round(2)
  end
  
  def error_rate
    return 0 if products_count.zero?
    ((errors_count.to_f / products_count) * 100).round(2)
  end
  
  def processing_time_seconds
    return 0 unless processing_time_ms
    (processing_time_ms / 1000.0).round(2)
  end
  
  def status
    return 'processing' if processed_count < products_count
    return 'completed_with_errors' if errors_count > 0
    'completed'
  end
  
  def file_changed?
    return true unless file_checksum # новый файл
    
    # Сравниваем с предыдущей версией
    previous_version = supplier.supplier_price_versions
                              .where.not(id: id)
                              .order(:uploaded_at)
                              .last
    
    return true unless previous_version&.file_checksum
    
    file_checksum != previous_version.file_checksum
  end
  
  private
  
  def generate_version
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    self.version = "#{supplier&.firm_id || 'unknown'}_#{timestamp}"
  end
end
