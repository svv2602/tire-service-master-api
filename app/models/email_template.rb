class EmailTemplate < ApplicationRecord
  # Связи
  has_many :email_template_custom_variables, dependent: :destroy
  has_many :custom_variables, through: :email_template_custom_variables

  # Валидации
  validates :name, presence: true, length: { maximum: 255 }
  validates :subject, presence: true, length: { maximum: 500 }
  validates :body, presence: true
  validates :template_type, presence: true, inclusion: { 
    in: %w[booking_confirmation booking_reminder booking_cancelled user_welcome password_reset review_request service_completed],
    message: "должен быть одним из допустимых типов"
  }
  validates :language, presence: true, inclusion: { in: %w[ru uk], message: "должен быть ru или uk" }
  validates :template_type, uniqueness: { 
    scope: :language, 
    message: "уже существует для данного языка" 
  }

  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :by_language, ->(lang) { where(language: lang) }

  # Методы
  def variables_array
    return [] if variables.blank?
    JSON.parse(variables)
  rescue JSON::ParserError
    []
  end

  def variables_array=(array)
    self.variables = array.to_json
  end

  def render_with_variables(variable_values = {})
    rendered_subject = subject.dup
    rendered_body = body.dup

    variables_array.each do |var|
      placeholder = "{#{var}}"
      value = variable_values[var.to_s] || variable_values[var.to_sym] || placeholder
      
      rendered_subject.gsub!(placeholder, value.to_s)
      rendered_body.gsub!(placeholder, value.to_s)
    end

    {
      subject: rendered_subject,
      body: rendered_body
    }
  end

  def self.template_types
    {
      'booking_confirmation' => 'Підтвердження бронювання',
      'booking_reminder' => 'Нагадування про бронювання',
      'booking_cancelled' => 'Скасування бронювання',
      'user_welcome' => 'Привітання нового користувача',
      'password_reset' => 'Скидання пароля',
      'review_request' => 'Запит на відгук',
      'service_completed' => 'Завершення послуги'
    }
  end

  def template_type_name
    self.class.template_types[template_type] || template_type.humanize
  end

  def status_text
    is_active? ? 'Активний' : 'Неактивний'
  end

  # Методы для работы с кастомными переменными
  def all_variables
    # Объединяем стандартные переменные и кастомные
    standard_vars = variables_array
    custom_vars = custom_variables.active.pluck(:name)
    
    (standard_vars + custom_vars).uniq
  end

  def custom_variables_by_category
    custom_variables.active.group_by(&:category)
  end

  def add_custom_variable(variable_name_or_id)
    if variable_name_or_id.is_a?(String)
      variable = CustomVariable.active.find_by(name: variable_name_or_id)
    else
      variable = CustomVariable.active.find(variable_name_or_id)
    end
    
    return false unless variable
    return true if custom_variables.include?(variable)
    
    custom_variables << variable
    true
  rescue ActiveRecord::RecordNotFound
    false
  end

  def remove_custom_variable(variable_name_or_id)
    if variable_name_or_id.is_a?(String)
      variable = custom_variables.find_by(name: variable_name_or_id)
    else
      variable = custom_variables.find(variable_name_or_id)
    end
    
    return false unless variable
    
    custom_variables.delete(variable)
    true
  rescue ActiveRecord::RecordNotFound
    false
  end

  def render_with_all_variables(variable_values = {})
    rendered_subject = subject.dup
    rendered_body = body.dup

    # Рендерим стандартные переменные
    variables_array.each do |var|
      placeholder = "{#{var}}"
      value = variable_values[var.to_s] || variable_values[var.to_sym] || placeholder
      
      rendered_subject.gsub!(placeholder, value.to_s)
      rendered_body.gsub!(placeholder, value.to_s)
    end

    # Рендерим кастомные переменные
    custom_variables.active.each do |custom_var|
      placeholder = custom_var.variable_placeholder
      value = variable_values[custom_var.name.to_s] || 
              variable_values[custom_var.name.to_sym] || 
              custom_var.example_value || 
              placeholder
      
      rendered_subject.gsub!(placeholder, value.to_s)
      rendered_body.gsub!(placeholder, value.to_s)
    end

    {
      subject: rendered_subject,
      body: rendered_body
    }
  end
end 