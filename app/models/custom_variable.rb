class CustomVariable < ApplicationRecord
  # Связи
  belongs_to :created_by, class_name: 'User'
  has_many :email_template_custom_variables, dependent: :destroy
  has_many :email_templates, through: :email_template_custom_variables

  # Валидации
  validates :name, presence: true, 
                   uniqueness: { case_sensitive: false },
                   length: { maximum: 100 },
                   format: { 
                     with: /\A[a-z_][a-z0-9_]*\z/, 
                     message: 'должно содержать только строчные буквы, цифры и подчеркивания, начинаться с буквы или подчеркивания'
                   }
  
  validates :category, presence: true, 
                       inclusion: { 
                         in: %w[client booking service_point time system custom],
                         message: 'должна быть одной из: client, booking, service_point, time, system, custom'
                       }
  
  validates :example_value, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }

  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :search, ->(query) { 
    where("LOWER(name) LIKE ? OR LOWER(description) LIKE ?", 
          "%#{query.downcase}%", "%#{query.downcase}%") 
  }

  # Методы
  def variable_placeholder
    "{#{name}}"
  end

  def category_name
    case category
    when 'client' then 'Клиент'
    when 'booking' then 'Бронирование'
    when 'service_point' then 'Сервисная точка'
    when 'time' then 'Время'
    when 'system' then 'Система'
    when 'custom' then 'Пользовательские'
    else category.humanize
    end
  end

  def self.categories
    {
      'client' => 'Клиент',
      'booking' => 'Бронирование', 
      'service_point' => 'Сервисная точка',
      'time' => 'Время',
      'system' => 'Система',
      'custom' => 'Пользовательские'
    }
  end

  def self.seed_default_variables
    default_variables = [
      # Клиент
      { name: 'client_name', category: 'client', description: 'Имя клиента', example_value: 'Иван Петренко' },
      { name: 'client_email', category: 'client', description: 'Email клиента', example_value: 'ivan@example.com' },
      { name: 'client_phone', category: 'client', description: 'Телефон клиента', example_value: '+380671234567' },
      
      # Бронирование
      { name: 'booking_date', category: 'booking', description: 'Дата бронирования', example_value: '2025-07-25' },
      { name: 'booking_time', category: 'booking', description: 'Время бронирования', example_value: '14:30' },
      { name: 'booking_id', category: 'booking', description: 'ID бронирования', example_value: '12345' },
      { name: 'service_name', category: 'booking', description: 'Название услуги', example_value: 'Замена шин' },
      
      # Сервисная точка
      { name: 'service_point_name', category: 'service_point', description: 'Название сервисной точки', example_value: 'СТО Центральный' },
      { name: 'service_point_address', category: 'service_point', description: 'Адрес сервисной точки', example_value: 'ул. Главная, 15' },
      { name: 'service_point_phone', category: 'service_point', description: 'Телефон сервисной точки', example_value: '+380441234567' },
      
      # Время
      { name: 'current_date', category: 'time', description: 'Текущая дата', example_value: '2025-07-21' },
      { name: 'current_time', category: 'time', description: 'Текущее время', example_value: '15:45' },
      
      # Система
      { name: 'company_name', category: 'system', description: 'Название компании', example_value: 'Tire Service Master' },
      { name: 'support_email', category: 'system', description: 'Email поддержки', example_value: 'support@tireservice.com' },
      { name: 'website_url', category: 'system', description: 'URL сайта', example_value: 'https://tireservice.com' }
    ]

    admin_user = User.find_by(email: 'admin@test.com') || User.first

    default_variables.each do |var_data|
      CustomVariable.find_or_create_by(name: var_data[:name]) do |var|
        var.category = var_data[:category]
        var.description = var_data[:description]
        var.example_value = var_data[:example_value]
        var.created_by = admin_user
      end
    end
  end
end
