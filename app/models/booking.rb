class Booking < ApplicationRecord
  # Подключаем стейт-машину для управления статусами
  include AASM
  
  # Связи
  belongs_to :client
  belongs_to :service_point
  belongs_to :car, class_name: 'ClientCar', optional: true
  belongs_to :car_type
  belongs_to :status, class_name: 'BookingStatus', foreign_key: 'status_id', required: true
  belongs_to :payment_status, optional: true
  belongs_to :cancellation_reason, optional: true
  has_many :booking_services, dependent: :destroy
  has_many :services, through: :booking_services
  has_one :review, dependent: :destroy
  
  # Валидации
  validates :booking_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :car_type_id, presence: true
  validates :client_id, presence: true
  validates :service_point_id, presence: true
  validates :status_id, presence: true
  validate :end_time_after_start_time
  validate :car_belongs_to_client, if: -> { car_id.present? }
  validate :valid_status_id, unless: -> { skip_status_validation || ENV['SWAGGER_DRY_RUN'] }
  validate :booking_time_available, on: :create, unless: -> { skip_availability_check }
  
  # Атрибуты для пропуска валидаций (нужны для тестов)
  attr_accessor :skip_status_validation, :skip_availability_check
  
  # Скоупы
  scope :upcoming, -> { where('booking_date >= ?', Date.current) }
  scope :past, -> { where('booking_date < ?', Date.current) }
  scope :today, -> { where(booking_date: Date.current) }
  scope :by_client, ->(client_id) { where(client_id: client_id) }
  scope :by_service_point, ->(service_point_id) { where(service_point_id: service_point_id) }
  scope :by_status, ->(status_id) { where(status_id: status_id) }
  scope :active, -> { where(status_id: BookingStatus.active_statuses) }
  scope :completed, -> { where(status_id: BookingStatus.completed_statuses) }
  scope :canceled, -> { where(status_id: BookingStatus.canceled_statuses) }
  
  # Скоупы для динамической проверки занятости
  scope :overlapping_time, ->(date, start_time, end_time) {
    where(booking_date: date)
      .where('start_time < ? AND end_time > ?', end_time, start_time)
      .where.not(status_id: BookingStatus.canceled_statuses)
  }
  
  scope :at_time, ->(date, time) {
    where(booking_date: date)
      .where('start_time <= ? AND end_time > ?', time, time)
      .where.not(status_id: BookingStatus.canceled_statuses)
  }
  
  # Helper method для получения имени статуса по ID
  def self.status_name_for_id(status_id)
    status = BookingStatus.find_by(id: status_id)
    status&.name || 'unknown'
  end
  
  # Метод для проверки доступности времени
  def self.available_posts_at_time(service_point_id, date, time)
    service_point = ServicePoint.find(service_point_id)
    total_posts = service_point.posts_count
    occupied_posts = at_time(date, time).where(service_point_id: service_point_id).count
    
    total_posts - occupied_posts
  end
  
  # Метод для резервирования времени (создание бронирования)
  def self.reserve_time(service_point_id, date, start_time, end_time, client_id, car_type_id, services_duration)
    # Проверяем доступность
    availability = DynamicAvailabilityService.check_availability_at_time(
      service_point_id, 
      date, 
      start_time, 
      services_duration
    )
    
    return { success: false, error: availability[:reason] } unless availability[:available]
    
    # Создаем бронирование
    booking = new(
      service_point_id: service_point_id,
      booking_date: date,
      start_time: start_time,
      end_time: end_time,
      client_id: client_id,
      car_type_id: car_type_id
    )
    
    if booking.save
      { success: true, booking: booking }
    else
      { success: false, error: booking.errors.full_messages.join(', ') }
    end
  end
  
  # Initialize statuses for AASM
  before_validation :initialize_status, on: :create, unless: -> { status_id.present? || ENV['SWAGGER_DRY_RUN'] }
  
  # Helper method for identifying the current state for AASM
  def aasm_read_state(name = :default)
    return nil unless status_id
    
    status_name = status&.name
    return nil unless status_name
    
    status_name.to_sym
  end
  
  # Helper method to write the state when AASM transitions happen
  def aasm_write_state(state, name = :default)
    status_name = state.to_s
    new_status = BookingStatus.find_by(name: status_name)
    
    if new_status
      update_columns(status_id: new_status.id)
      reload # ensure the status association is refreshed
    else
      Rails.logger.error("BookingStatus with name '#{status_name}' not found")
      return false
    end
    
    true
  end
  
  # AASM для управления статусами с использованием имен статусов
  aasm column: :status_id, enum: false, no_direct_assignment: false, whiny_persistence: false do
    # Define states with proper initialization
    state :pending, initial: true, value: -> { BookingStatus.pending_id }
    state :confirmed, value: -> { BookingStatus.confirmed_id }
    state :in_progress, value: -> { BookingStatus.in_progress_id }
    state :completed, value: -> { BookingStatus.completed_id }
    state :canceled_by_client, value: -> { BookingStatus.canceled_by_client_id }
    state :canceled_by_partner, value: -> { BookingStatus.canceled_by_partner_id }
    state :no_show, value: -> { BookingStatus.no_show_id }
    
    event :confirm do
      transitions from: :pending, to: :confirmed
    end
    
    event :start_service do
      transitions from: :confirmed, to: :in_progress
    end
    
    event :complete do
      transitions from: [:confirmed, :in_progress], to: :completed
    end
    
    event :cancel_by_client do
      transitions from: [:pending, :confirmed], to: :canceled_by_client
    end
    
    event :cancel_by_partner do
      transitions from: [:pending, :confirmed], to: :canceled_by_partner
    end
    
    event :mark_no_show do
      transitions from: [:confirmed], to: :no_show
    end
  end
  
  # Метод для пропуска валидаций AASM при создании в тестах
  def validation_skip_for_aasm
    self.skip_status_validation = true
    self.skip_availability_check = true
    self
  end
  
  # Методы
  def total_duration_minutes
    minutes_start = start_time.hour * 60 + start_time.min
    minutes_end = end_time.hour * 60 + end_time.min
    minutes_end - minutes_start
  end
  
  def calculate_total_price
    booking_services.sum("price * quantity")
  end
  
  def update_total_price!
    update(total_price: calculate_total_price)
  end
  
  # Проверка пересечения с другими бронированиями
  def overlaps_with_other_bookings?
    overlapping = self.class.overlapping_time(booking_date, start_time, end_time)
                     .where(service_point_id: service_point_id)
                     
    # Исключаем текущее бронирование если оно уже существует
    overlapping = overlapping.where.not(id: id) if persisted?
    
    overlapping.exists?
  end
  
  private
  
  # Initialize the status to pending if not set
  def initialize_status
    self.status_id = BookingStatus.pending_id if status_id.nil?
  end
  
  def end_time_after_start_time
    return unless start_time && end_time
    
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
  
  def car_belongs_to_client
    return unless car_id.present?
    
    unless car&.client_id == client_id
      errors.add(:car_id, "must belong to the client")
    end
  end
  
  def valid_status_id
    # Skip validation for tests or when SWAGGER_DRY_RUN is active
    return true if skip_status_validation || ENV['SWAGGER_DRY_RUN']
    
    # Check if status exists
    unless BookingStatus.exists?(status_id)
      errors.add(:status_id, "is invalid")
    end
  end
  
  # Валидация доступности времени бронирования
  def booking_time_available
    return if skip_availability_check
    
    # Проверяем что время в рабочих часах
    availability = DynamicAvailabilityService.check_availability_at_time(
      service_point_id,
      booking_date,
      start_time,
      total_duration_minutes
    )
    
    unless availability[:available]
      errors.add(:base, "Время недоступно: #{availability[:reason]}")
    end
    
    # Проверяем пересечения с другими бронированиями
    if overlaps_with_other_bookings?
      available_posts = self.class.available_posts_at_time(service_point_id, booking_date, start_time)
      if available_posts <= 0
        errors.add(:base, "Все посты заняты на выбранное время")
      end
    end
  end
end
