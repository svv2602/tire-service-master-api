class TelegramBookingSession < ApplicationRecord
  # Константы шагов бронирования
  BOOKING_STEPS = {
    city_selection: 'city_selection',
    service_selection: 'service_selection', 
    service_point_selection: 'service_point_selection',
    datetime_selection: 'datetime_selection',
    car_type_selection: 'car_type_selection',
    phone_input: 'phone_input',
    license_plate_input: 'license_plate_input',
    comment_input: 'comment_input',
    confirmation: 'confirmation'
  }.freeze

  # Валидации
  validates :chat_id, presence: true, uniqueness: true
  validates :current_step, presence: true, inclusion: { in: BOOKING_STEPS.values }
  validates :expires_at, presence: true

  # Скоупы
  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  # Обратные вызовы
  before_create :set_expiration_time
  before_validation :set_expiration_time, on: :create

  # Методы для работы с данными сессии
  def update_step(step, data = {})
    self.current_step = step
    self.session_data = self.session_data.merge(data)
    self.expires_at = 1.hour.from_now
    save!
  end

  def get_data(key)
    session_data[key.to_s]
  end

  def set_data(key, value)
    self.session_data = session_data.merge(key.to_s => value)
  end

  def clear_data!
    self.session_data = {}
    save!
  end

  def expired?
    expires_at <= Time.current
  end

  def extend_session!
    update!(expires_at: 1.hour.from_now)
  end

  # Методы для навигации по шагам
  def next_step
    steps = BOOKING_STEPS.values
    current_index = steps.index(current_step)
    return nil if current_index.nil? || current_index >= steps.length - 1
    
    steps[current_index + 1]
  end

  def previous_step
    steps = BOOKING_STEPS.values
    current_index = steps.index(current_step)
    return nil if current_index.nil? || current_index <= 0
    
    steps[current_index - 1]
  end

  # Методы для получения данных бронирования
  def booking_data
    {
      city_id: get_data(:city_id),
      service_category_id: get_data(:service_category_id),
      service_point_id: get_data(:service_point_id),
      date: get_data(:date),
      time: get_data(:time),
      car_type_id: get_data(:car_type_id),
      phone: get_data(:phone),
      license_plate: get_data(:license_plate),
      comment: get_data(:comment)
    }
  end

  def ready_for_booking?
    required_fields = [:city_id, :service_category_id, :service_point_id, :date, :time, :car_type_id, :phone, :license_plate]
    required_fields.all? { |field| get_data(field).present? }
  end

  private

  def set_expiration_time
    self.expires_at = 1.hour.from_now if self.expires_at.blank?
  end
end
