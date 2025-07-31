class TireDataVersion < ApplicationRecord
  # Валидации
  validates :version, presence: true, uniqueness: true
  validates :version, format: { 
    with: /\A\d{4}\.\d{1,2}\z/, 
    message: 'должна быть в формате YYYY.N (например, 2025.1)' 
  }
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :by_date, -> { order(:imported_at) }
  scope :recent, -> { order(imported_at: :desc) }
  
  # Колбэки
  before_create :set_imported_at
  after_create :deactivate_previous_versions, if: :is_active?
  
  # Методы класса
  def self.current
    active.order(:imported_at).last
  end
  
  def self.latest_version
    current&.version || '2025.1'
  end
  
  def self.create_new_version!(version, description = nil, checksums = {}, stats = {})
    create!(
      version: version,
      source_description: description || "Обновление данных шин до версии #{version}",
      file_checksums: checksums,
      statistics: stats,
      imported_at: Time.current,
      is_active: true
    )
  end
  
  def self.rollback_to_version!(target_version)
    target = find_by!(version: target_version)
    
    transaction do
      # Деактивируем текущую версию
      current&.update!(is_active: false)
      
      # Активируем целевую версию
      target.update!(is_active: true)
      
      # Обновляем конфигурации шин
      CarTireConfiguration.where(is_deprecated: false)
                          .update_all(is_deprecated: true)
      
      CarTireConfiguration.where(data_version: target_version)
                          .update_all(is_deprecated: false)
    end
    
    target
  end
  
  def self.cleanup_old_versions!(keep_count = 5)
    old_versions = order(imported_at: :desc).offset(keep_count)
    
    old_versions.each do |version|
      # Удаляем связанные конфигурации
      CarTireConfiguration.where(data_version: version.version).delete_all
      # Удаляем версию
      version.destroy
    end
  end
  
  def self.version_statistics
    {
      total_versions: count,
      active_version: current&.version,
      oldest_version: order(:imported_at).first&.version,
      newest_version: order(:imported_at).last&.version,
      configurations_count: CarTireConfiguration.active.not_deprecated.count
    }
  end
  
  # Методы экземпляра
  def activate!
    transaction do
      # Деактивируем все остальные версии
      self.class.where.not(id: id).update_all(is_active: false)
      
      # Активируем эту версию
      update!(is_active: true)
      
      # Обновляем статус конфигураций
      CarTireConfiguration.update_all(is_deprecated: true)
      CarTireConfiguration.where(data_version: version)
                          .update_all(is_deprecated: false)
    end
  end
  
  def deactivate!
    update!(is_active: false)
  end
  
  def configurations_count
    CarTireConfiguration.where(data_version: version).count
  end
  
  def active_configurations_count
    CarTireConfiguration.where(data_version: version, is_deprecated: false).count
  end
  
  def brands_count
    statistics&.dig('brands') || 0
  end
  
  def models_count
    statistics&.dig('models') || 0
  end
  
  def total_tire_sizes
    statistics&.dig('tire_sizes') || 0
  end
  
  def file_count
    file_checksums&.keys&.count || 0
  end
  
  def total_file_size
    statistics&.dig('total_file_size') || 0
  end
  
  def formatted_file_size
    return '0 B' if total_file_size.zero?
    
    units = %w[B KB MB GB TB]
    size = total_file_size.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(2)} #{units[unit_index]}"
  end
  
  def age_in_days
    return 0 unless imported_at
    
    ((Time.current - imported_at) / 1.day).round
  end
  
  def is_outdated?(threshold_days = 180)
    age_in_days > threshold_days
  end
  
  def can_be_deleted?
    !is_active? && age_in_days > 30 && configurations_count.zero?
  end
  
  def summary
    {
      version: version,
      description: source_description,
      imported_at: imported_at,
      is_active: is_active,
      age_days: age_in_days,
      brands: brands_count,
      models: models_count,
      configurations: configurations_count,
      active_configurations: active_configurations_count,
      file_size: formatted_file_size
    }
  end
  
  # JSON сериализация для API
  def as_json(options = {})
    super(options.merge(
      methods: [
        :configurations_count, 
        :active_configurations_count,
        :brands_count,
        :models_count,
        :total_tire_sizes,
        :formatted_file_size,
        :age_in_days,
        :is_outdated?,
        :can_be_deleted?
      ]
    ))
  end
  
  private
  
  def set_imported_at
    self.imported_at ||= Time.current
  end
  
  def deactivate_previous_versions
    return unless is_active?
    
    self.class.where.not(id: id).update_all(is_active: false)
  end
end