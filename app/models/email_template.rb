class EmailTemplate < ApplicationRecord
  # Связи
  has_many :email_template_custom_variables, dependent: :destroy
  has_many :custom_variables, through: :email_template_custom_variables

  # Валидации
  validates :name, presence: true, length: { maximum: 255 }
  validates :template_type, presence: true
  validates :language, presence: true, inclusion: { in: %w[uk ru en] }
  validates :channel_type, presence: true, inclusion: { in: %w[email telegram push] }
  validates :body, presence: true
  validates :template_type, uniqueness: { scope: [:language, :channel_type] }
  
  # Условная валидация subject в зависимости от канала
  validates :subject, presence: true, if: -> { email_channel? || push_channel? }
  validates :subject, absence: true, if: -> { telegram_channel? }

  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :by_language, ->(lang) { where(language: lang) }
  scope :by_channel, ->(channel) { where(channel_type: channel) }
  scope :email_templates, -> { where(channel_type: 'email') }
  scope :telegram_templates, -> { where(channel_type: 'telegram') }
  scope :push_templates, -> { where(channel_type: 'push') }

  # Методы проверки типа канала
  def email_channel?
    channel_type == 'email'
  end

  def telegram_channel?
    channel_type == 'telegram'
  end

  def push_channel?
    channel_type == 'push'
  end

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
    rendered_subject = email_channel? ? subject.dup : nil
    rendered_body = body.dup

    variables_array.each do |var|
      placeholder = "{#{var}}"
      value = variable_values[var.to_s] || variable_values[var.to_sym] || placeholder
      
      rendered_subject&.gsub!(placeholder, value.to_s)
      rendered_body.gsub!(placeholder, value.to_s)
    end

    result = { body: rendered_body }
    result[:subject] = rendered_subject if rendered_subject
    result
  end

  # Обновленный метод для работы с каналами
  def render_for_channel(variable_values = {})
    case channel_type
    when 'email'
      render_email_template(variable_values)
    when 'telegram'
      render_telegram_template(variable_values)
    when 'push'
      render_push_template(variable_values)
    else
      render_with_variables(variable_values)
    end
  end

  def self.template_types
    {
      # Основные события системы (реально используемые)
      'booking_confirmation' => 'Подтверждение бронирования',
      'booking_cancelled' => 'Отмена бронирования', 
      'booking_reminder' => 'Напоминание о записи',
      'service_completed' => 'Завершение обслуживания',
      'review_request' => 'Запрос отзыва',
      'user_welcome' => 'Приветствие нового пользователя',
      'password_reset' => 'Сброс пароля',
      'newsletter' => 'Информационная рассылка'
    }
  end

  # Типы шаблонов по каналам
  def self.template_types_for_channel(channel_type)
    case channel_type.to_s
    when 'email'
      {
        'booking_confirmation' => 'Подтверждение бронирования',
        'booking_cancelled' => 'Отмена бронирования', 
        'booking_reminder' => 'Напоминание о записи',
        'service_completed' => 'Завершение обслуживания',
        'review_request' => 'Запрос отзыва',
        'user_welcome' => 'Приветствие нового пользователя',
        'password_reset' => 'Сброс пароля',
        'newsletter' => 'Информационная рассылка'
      }
    when 'telegram'
      {
        'booking_confirmation' => 'Подтверждение бронирования',
        'booking_cancelled' => 'Отмена бронирования',
        'booking_reminder' => 'Напоминание о записи', 
        'service_completed' => 'Завершение обслуживания',
        'review_request' => 'Запрос отзыва',
        'newsletter' => 'Информационная рассылка'
      }
    when 'push'
      {
        'booking_confirmation' => 'Подтверждение бронирования',
        'booking_cancelled' => 'Отмена бронирования',
        'booking_reminder' => 'Напоминание о записи',
        'service_completed' => 'Завершение обслуживания',
        'review_request' => 'Запрос отзыва'
      }
    else
      template_types
    end
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
    rendered_subject = email_channel? ? subject.dup : nil
    rendered_body = body.dup

    # Рендерим ВСЕ переданные переменные (основная логика)
    variable_values.each do |key, value|
      placeholder = "{#{key}}"
      rendered_subject&.gsub!(placeholder, value.to_s)
      rendered_body.gsub!(placeholder, value.to_s)
    end

    # Рендерим стандартные переменные (для обратной совместимости)
    variables_array.each do |var|
      placeholder = "{#{var}}"
      value = variable_values[var.to_s] || variable_values[var.to_sym] || placeholder
      
      rendered_subject&.gsub!(placeholder, value.to_s)
      rendered_body.gsub!(placeholder, value.to_s)
    end

    result = { body: rendered_body }
    result[:subject] = rendered_subject if rendered_subject
    result
  end

  # Методы рендеринга для разных каналов
  def render_email_template(variable_values = {})
    rendered = render_with_all_variables(variable_values)
    {
      subject: rendered[:subject],
      body: rendered[:body],
      content_type: 'text/html'
    }
  end

  def render_telegram_template(variable_values = {})
    rendered = render_with_all_variables(variable_values)
    {
      message: rendered[:body],
      parse_mode: 'HTML', # или 'Markdown'
      disable_web_page_preview: true
    }
  end

  def render_push_template(variable_values = {})
    rendered = render_with_all_variables(variable_values)
    {
      title: name, # Используем название шаблона как заголовок
      body: rendered[:body],
      icon: get_push_icon_for_template_type,
      badge: get_push_badge_for_template_type,
      data: variable_values.slice(:booking_id, :review_id, :service_point_id) # Дополнительные данные
    }
  end

  # Методы для получения иконок и бэджей для push уведомлений
  def get_push_icon_for_template_type
    case template_type
    when /booking/ then '/icons/booking.png'
    when /review/ then '/icons/review.png'
    when /service/ then '/icons/service.png'
    when /password/ then '/icons/security.png'
    when /welcome/ then '/icons/welcome.png'
    else '/icons/notification.png'
    end
  end

  def get_push_badge_for_template_type
    case template_type
    when /booking/ then 'booking'
    when /review/ then 'review'
    when /service/ then 'service'
    else 'general'
    end
  end

  # Статический метод для получения доступных каналов
  def self.available_channels
    {
      'email' => 'Email',
      'telegram' => 'Telegram',
      'push' => 'Push уведомления'
    }
  end

  # Метод для получения названия канала
  def channel_name
    self.class.available_channels[channel_type] || channel_type.humanize
  end

  # Проверка совместимости шаблона с каналом
  def compatible_with_channel?(channel)
    case channel
    when 'email'
      subject.present? && body.present?
    when 'telegram'
      body.present? && body.length <= 4096 # Лимит Telegram
    when 'push'
      body.present? && body.length <= 160 # Лимит push уведомлений
    else
      false
    end
  end
end 