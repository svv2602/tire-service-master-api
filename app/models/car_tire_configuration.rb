class CarTireConfiguration < ApplicationRecord
  # Связи
  belongs_to :brand, class_name: 'CarBrand'
  belongs_to :model, class_name: 'CarModel'
  
  # Валидации
  validates :year_from, presence: true, numericality: { greater_than: 1900, less_than: 2100 }
  validates :year_to, presence: true, numericality: { greater_than: 1900, less_than: 2100 }
  validates :tire_sizes, presence: true
  validates :data_version, presence: true
  
  validate :year_range_valid
  validate :tire_sizes_format
  
  # Скоупы для поиска
  scope :active, -> { where(is_active: true) }
  scope :not_deprecated, -> { where(is_deprecated: false) }
  scope :current_version, ->(version = nil) { where(data_version: version || current_data_version) }
  
  # Поиск по естественному запросу
  scope :search_by_query, ->(query) {
    return none if query.blank?
    
    query = query.downcase.strip
    
    joins(:brand, :model).where(
      "LOWER(car_brands.name) LIKE ? OR 
       LOWER(car_models.name) LIKE ? OR
       LOWER(search_tokens) LIKE ? OR
       search_aliases::text ILIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
    )
  }
  
  # Поиск по диаметру шин
  scope :with_diameter, ->(diameter) {
    return none if diameter.blank?
    
    where("tire_sizes @> ?", [{"diameter" => diameter.to_i}].to_json)
  }
  
  # Поиск по ширине шин
  scope :with_width, ->(width) {
    return none if width.blank?
    
    where("tire_sizes @> ?", [{"width" => width.to_i}].to_json)
  }
  
  # Поиск по году выпуска
  scope :for_year, ->(year) {
    return none if year.blank?
    
    year = year.to_i
    where("year_from <= ? AND year_to >= ?", year, year)
  }
  
  # Поиск по бренду
  scope :for_brand, ->(brand_name) {
    return none if brand_name.blank?
    
    joins(:brand).where("LOWER(car_brands.name) = ?", brand_name.downcase)
  }
  
  # Поиск по модели
  scope :for_model, ->(model_name) {
    return none if model_name.blank?
    
    joins(:model).where("LOWER(car_models.name) = ?", model_name.downcase)
  }
  
  # Сортировка по релевантности
  scope :by_relevance, ->(query = nil) {
    return order(:brand_id, :model_id, :year_from) if query.blank?
    
    query = query.downcase
    
    select("car_tire_configurations.*, 
            CASE 
              WHEN LOWER(car_brands.name) = '#{query}' THEN 100
              WHEN LOWER(car_models.name) = '#{query}' THEN 90
              WHEN LOWER(car_brands.name) LIKE '#{query}%' THEN 80
              WHEN LOWER(car_models.name) LIKE '#{query}%' THEN 70
              WHEN search_tokens ILIKE '%#{query}%' THEN 60
              ELSE 50
            END as relevance_score")
      .joins(:brand, :model)
      .order('relevance_score DESC, car_brands.name, car_models.name, year_from DESC')
  }
  
  # Методы класса
  def self.current_data_version
    TireDataVersion.where(is_active: true).order(:created_at).last&.version || '2025.1'
  end
  
  def self.search_with_filters(params = {})
    scope = active.not_deprecated
    
    # Основной поиск
    scope = scope.search_by_query(params[:query]) if params[:query].present?
    
    # Фильтры
    scope = scope.for_brand(params[:brand]) if params[:brand].present?
    scope = scope.for_model(params[:model]) if params[:model].present?
    scope = scope.for_year(params[:year]) if params[:year].present?
    scope = scope.with_diameter(params[:diameter]) if params[:diameter].present?
    scope = scope.with_width(params[:width]) if params[:width].present?
    scope = scope.current_version(params[:data_version]) if params[:data_version].present?
    
    # Сортировка
    scope = scope.by_relevance(params[:query])
    
    scope.includes(:brand, :model)
  end
  
  # Методы экземпляра
  def full_name
    "#{brand.name} #{model.name} (#{year_from}-#{year_to})"
  end
  
  def year_range
    year_from == year_to ? year_from.to_s : "#{year_from}-#{year_to}"
  end
  
  def stock_tire_sizes
    tire_sizes&.select { |size| size['type'] == 'stock' } || []
  end
  
  def optional_tire_sizes
    tire_sizes&.select { |size| size['type'] == 'optional' } || []
  end
  
  def all_diameters
    tire_sizes&.map { |size| size['diameter'] }&.uniq&.sort || []
  end
  
  def formatted_tire_sizes
    return [] if tire_sizes.blank?
    
    tire_sizes.map do |size|
      "#{size['width']}/#{size['height']}R#{size['diameter']}"
    end.uniq.sort
  end
  
  def update_search_tokens!
    tokens = [
      brand.name,
      model.name,
      search_aliases&.join(' '),
      year_from.to_s,
      year_to.to_s,
      formatted_tire_sizes.join(' ')
    ].compact.join(' ').downcase
    
    update_column(:search_tokens, tokens)
  end
  
  # JSON сериализация для API
  def as_json(options = {})
    super(options.merge(
      include: {
        brand: { only: [:id, :name] },
        model: { only: [:id, :name] }
      },
      methods: [:full_name, :year_range, :formatted_tire_sizes, :stock_tire_sizes, :optional_tire_sizes]
    ))
  end
  
  private
  
  def year_range_valid
    return unless year_from && year_to
    
    if year_from > year_to
      errors.add(:year_to, 'должен быть больше или равен году начала')
    end
    
    # Отключаем валидацию диапазона для импорта данных
    # (исторические данные могут иметь большие диапазоны)
    # if year_to - year_from > 100
    #   errors.add(:year_to, 'диапазон лет не может превышать 100 лет')
    # end
  end
  
  def tire_sizes_format
    return if tire_sizes.blank?
    
    unless tire_sizes.is_a?(Array)
      errors.add(:tire_sizes, 'должен быть массивом')
      return
    end
    
    tire_sizes.each_with_index do |size, index|
      unless size.is_a?(Hash)
        errors.add(:tire_sizes, "элемент #{index + 1} должен быть объектом")
        next
      end
      
      required_fields = %w[width height diameter type]
      missing_fields = required_fields - size.keys.map(&:to_s)
      
      if missing_fields.any?
        errors.add(:tire_sizes, "элемент #{index + 1} должен содержать поля: #{missing_fields.join(', ')}")
      end
      
      if size['type'] && !%w[stock optional].include?(size['type'])
        errors.add(:tire_sizes, "элемент #{index + 1}: тип должен быть 'stock' или 'optional'")
      end
      
      %w[width height diameter].each do |field|
        value = size[field]
        if value && (!value.is_a?(Numeric) || value <= 0)
          errors.add(:tire_sizes, "элемент #{index + 1}: #{field} должен быть положительным числом")
        end
      end
    end
  end
end