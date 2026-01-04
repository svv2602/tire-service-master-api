class SupplierTireProduct < ApplicationRecord
  # Связи
  belongs_to :supplier
  belongs_to :tire_brand, optional: true
  belongs_to :tire_model, optional: true
  belongs_to :country, optional: true
  has_many :tire_order_items, dependent: :destroy
  has_many :tire_orders, through: :tire_order_items
  
  # Константы для сезонности
  SEASONS = {
    'Зимові шини' => 'winter',
    'Літні шини' => 'summer', 
    'Всесезонні шини' => 'all_season'
  }.freeze
  
  # Валидации
  validates :external_id, presence: true, length: { maximum: 255 }
  validates :original_brand, presence: true, length: { maximum: 100 }
  validates :original_model, presence: true, length: { maximum: 255 }
  validates :name, presence: true, length: { maximum: 500 }
  validates :width, presence: true, numericality: { greater_than: 0 }
  validates :height, presence: true, numericality: { greater_than: 0 }
  validates :diameter, presence: true, length: { maximum: 10 }
  validates :season, presence: true, inclusion: { in: SEASONS.values }
  validates :price_uah, numericality: { greater_than: 0 }, allow_nil: true
  
  # Уникальность товара у поставщика
  validates :external_id, uniqueness: { scope: :supplier_id }
  
  # Скоупы
  scope :in_stock, -> { where(in_stock: true) }
  scope :by_brand, ->(brand_id) { where(tire_brand_id: brand_id) }
  scope :by_brand_name, ->(brand_name) { 
    joins(:tire_brand).where(tire_brands: { normalized_name: TireBrand.send(:normalize_string, brand_name) })
  }
  scope :by_season, ->(season) { where(season: season) }
  scope :by_country, ->(country_id) { where(country_id: country_id) }
  scope :by_model, ->(model_id) { where(tire_model_id: model_id) }
  scope :normalized, -> { where.not(tire_brand_id: nil) }
  scope :not_normalized, -> { where(tire_brand_id: nil) }
  scope :by_optimality, ->(min_score) { where('optimality_score >= ?', min_score) }
  scope :top_optimality, ->(limit = 10) { order(optimality_score: :desc).limit(limit) }
  scope :by_size, ->(width, height, diameter) { 
    where(width: width, height: height, diameter: diameter) 
  }
  scope :search_by_text, ->(query) {
    return all if query.blank?
    
    # Разбиваем запрос на отдельные слова для поиска с условием "И"
    words = query.strip.split(/[\s\/]+/).reject(&:blank?).map(&:strip)
    return all if words.empty?
    
    # Создаем условия для каждого слова (все слова должны быть найдены)
    conditions = []
    params = []
    
    words.each do |word|
      sanitized_word = "%#{word}%"
      conditions << '(original_brand ILIKE ? OR original_model ILIKE ? OR name ILIKE ? OR external_id ILIKE ? OR description ILIKE ?)'
      params += [sanitized_word, sanitized_word, sanitized_word, sanitized_word, sanitized_word]
    end
    
    # Объединяем условия через AND для поиска всех слов
    where(conditions.join(' AND '), *params)
  }
  scope :updated_after, ->(date) { 
    return all if date.blank?
    where('updated_at >= ?', date) 
  }
  scope :updated_before, ->(date) { 
    return all if date.blank?
    where('updated_at <= ?', date) 
  }
  scope :updated_between, ->(start_date, end_date) {
    return all if start_date.blank? && end_date.blank?
    query = all
    query = query.updated_after(start_date) if start_date.present?
    query = query.updated_before(end_date) if end_date.present?
    query
  }
  scope :by_search_params, ->(params) {
    query = all
    query = query.by_brand(params[:brand]) if params[:brand].present?
    query = query.by_season(params[:season]) if params[:season].present?
    query = query.by_size(params[:width], params[:height], params[:diameter]) if params[:width].present?
    query = query.in_stock if params[:in_stock_only]
    query
  }
  scope :grouped_by_tire_params, -> {
    select('brand_normalized, model, width, height, diameter, load_index, speed_index, season, 
            COUNT(*) as suppliers_count, 
            MIN(price_uah) as min_price, 
            MAX(price_uah) as max_price,
            ARRAY_AGG(DISTINCT supplier_id) as supplier_ids')
    .where(in_stock: true)
    .group('brand_normalized, model, width, height, diameter, load_index, speed_index, season')
    .having('COUNT(*) > 0')
  }
  
  # Колбэки
  before_validation :normalize_brand_name
  before_validation :normalize_season
  before_validation :set_in_stock_status
  before_save :update_search_tokens
  
  # Методы класса
  def self.normalize_brand(brand_name)
    return nil if brand_name.blank?
    
    # Нормализация популярных брендов
    normalized = brand_name.strip.downcase
    brand_mapping = {
      'goodyear' => 'Goodyear',
      'michelin' => 'Michelin',
      'bridgestone' => 'Bridgestone',
      'continental' => 'Continental',
      'pirelli' => 'Pirelli',
      'dunlop' => 'Dunlop',
      'yokohama' => 'Yokohama',
      'hankook' => 'Hankook',
      'kumho' => 'Kumho',
      'nokian' => 'Nokian'
    }
    
    brand_mapping[normalized] || brand_name.strip.titleize
  end
  
  def self.search_by_query(query_params)
    # Основной поиск с группировкой
    products = by_search_params(query_params)
                .includes(:supplier)
                .order(:brand_normalized, :model, :width, :height, :diameter, :price_uah)
    
    # Группируем по параметрам шин
    grouped = products.group_by do |product|
      "#{product.brand_normalized}|#{product.original_model}|#{product.width}/#{product.height}R#{product.diameter}|#{product.load_index}#{product.speed_index}"
    end
    
    # Преобразуем в структуру для фронтенда
    grouped.map do |tire_key, tire_products|
      first_product = tire_products.first
      {
        tire_key: tire_key,
        brand: first_product.brand_normalized,
        model: first_product.original_model,
        size: "#{first_product.width}/#{first_product.height}R#{first_product.diameter}",
        load_speed_index: "#{first_product.load_index}#{first_product.speed_index}",
        season: first_product.season,
        suppliers_count: tire_products.length,
        min_price: tire_products.map(&:price_uah).compact.min,
        max_price: tire_products.map(&:price_uah).compact.max,
        products: tire_products.map { |p| format_product_for_api(p) }
      }
    end
  end
  
  def self.format_product_for_api(product)
    {
      id: product.id,
      supplier_name: product.supplier.name,
      supplier_priority: product.supplier.priority,
      name: product.name,
      price_uah: product.price_uah,
      stock_status: product.stock_status,
      image_url: product.image_url,
      product_url: product.product_url,
      country: product.country,
      year_week: product.year_week
    }
  end
  
  # Методы экземпляра
  def tire_size
    "#{width}/#{height}R#{diameter}"
  end
  
  def load_speed_indices
    "#{load_index}#{speed_index}"
  end
  
  def season_display
    SEASONS.key(season) || season
  end
  
  def formatted_price
    return 'Цена не указана' unless price_uah
    "#{price_uah.to_i} грн"
  end

  # === МЕТОДЫ ДЛЯ НОРМАЛИЗАЦИИ И ОЦЕНКИ ===

  # Автоматическая нормализация при сохранении
  def auto_normalize!
    TireDataNormalizer.normalize_product(self)
  end

  # Расчет рейтинга оптимальности
  def calculate_optimality_score(options = {})
    TireOptimalityCalculator.calculate_optimality(self, options)
  end

  # Обновление рейтинга оптимальности
  def update_optimality_score!(options = {})
    score = calculate_optimality_score(options)
    update_column(:optimality_score, score)
    score
  end

  # Получение полного названия с брендом и моделью
  def full_normalized_name
    return name if tire_brand.blank? && tire_model.blank?
    
    parts = []
    parts << tire_brand.name if tire_brand
    parts << tire_model.name if tire_model
    parts << size_designation
    parts.join(' ')
  end

  # Обозначение размера
  def size_designation
    "#{width}/#{height}R#{diameter}"
  end

  # Проверка нормализации
  def normalized?
    tire_brand_id.present?
  end

  # Получение детальной информации для чата
  def chat_description
    parts = []
    parts << "#{tire_brand&.name || original_brand} #{tire_model&.name || original_model}"
    parts << size_designation
    parts << "#{season.capitalize} #{production_year}" if production_year
    parts << "#{price_uah} грн" if price_uah
    parts << "(рейтинг: #{optimality_score})" if optimality_score
    parts.join(' ')
  end

  # Получение причин рекомендации
  def recommendation_reasons
    reasons = []
    
    if tire_brand&.is_premium
      reasons << "премиум бренд"
    end
    
    if optimality_score && optimality_score >= 8
      reasons << "высокий рейтинг качества"
    end
    
    if production_year && production_year >= Time.current.year - 1
      reasons << "новая модель"
    end
    
    if country&.rating_score && country.rating_score >= 8
      reasons << "качественное производство"
    end
    
    reasons.empty? ? ["хорошее соотношение цена-качество"] : reasons
  end
  
  private
  
  def normalize_brand_name
    # Этот метод больше не нужен, так как нормализация происходит через TireDataNormalizer
    # self.brand_normalized = self.class.normalize_brand(original_brand)
  end
  
  def normalize_season
    if season.present? && SEASONS.key?(season)
      self.season = SEASONS[season]
    end
  end
  
  def set_in_stock_status
    return if stock_status.blank?

    # If in_stock was explicitly changed but stock_status wasn't, respect the explicit change
    return if in_stock_changed? && !stock_status_changed?

    # Match both Ukrainian and English out-of-stock patterns
    out_of_stock_patterns = /не\s*в\s*наявності|немає|відсутній|out_of_stock|archived/i
    self.in_stock = !stock_status.match?(out_of_stock_patterns)
  end
  
  def update_search_tokens
    tokens = [
      original_brand, tire_brand&.name, original_model, tire_model&.name, name,
      tire_size, load_speed_indices,
      original_country, country&.name, season_display
    ].compact.join(' ')
    
    self.search_tokens = tokens
  end
  
end
