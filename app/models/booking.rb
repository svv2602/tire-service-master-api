class Booking < ApplicationRecord
  # Подключаем модуль со статусами
  include BookingStatuses
  
  # Связи
  belongs_to :client, optional: true  # ✅ Делаем связь опциональной для гостевых бронирований
  belongs_to :service_point
  belongs_to :car, class_name: 'ClientCar', optional: true
  belongs_to :car_type
  # Оставляем связь со старой таблицей статусов для совместимости (опционально)
  belongs_to :booking_status, class_name: 'BookingStatus', foreign_key: 'status_id', optional: true
  belongs_to :payment_status, optional: true
  belongs_to :cancellation_reason, optional: true
  belongs_to :service_category, optional: true
  has_many :booking_services, dependent: :destroy
  has_many :services, through: :booking_services
  has_one :review, dependent: :destroy
  
  # Валидации
  validates :booking_date, presence: true
  validates :start_time, presence: true
  # end_time не обязателен при создании - может быть NULL в слотовой архитектуре
  validates :car_type_id, presence: true
  # validates :client_id, presence: true  # ❌ Убираем обязательную валидацию client_id
  validates :service_point_id, presence: true
  # Валидация статуса теперь в модуле BookingStatuses
  
  # Валидации для получателя услуги
  validates :service_recipient_first_name, presence: true, length: { maximum: 100 }
  validates :service_recipient_last_name, presence: true, length: { maximum: 100 }
  validates :service_recipient_phone, presence: true, format: { 
    with: /\A\+?[\d\s\-\(\)]+\z/, 
    message: 'должен содержать только цифры, пробелы, дефисы и скобки' 
  }
  validates :service_recipient_email, format: { 
    with: URI::MailTo::EMAIL_REGEXP, 
    message: 'имеет неверный формат' 
  }, allow_blank: true
  
  validate :end_time_after_start_time
  validate :car_belongs_to_client, if: -> { car_id.present? }
  validate :booking_time_available, on: :create, unless: -> { skip_availability_check }
  validate :service_category_matches_service_point, if: :service_category_id?
  
  # Атрибуты для пропуска валидаций (нужны для тестов)
  attr_accessor :skip_availability_check, :skip_notifications
  
  # Коллбэки для отправки уведомлений
  after_create :send_creation_notification, unless: -> { skip_notifications }
  after_update :send_status_change_notification, if: -> { saved_change_to_status? && !skip_notifications }
  
  # Инициализация статуса при создании
  before_validation :initialize_status, on: :create, unless: -> { status.present? }
  
  # Скоупы (обновленные для работы со строковыми статусами)
  scope :upcoming, -> { where('booking_date >= ?', Date.current) }
  scope :past, -> { where('booking_date < ?', Date.current) }
  scope :today, -> { where(booking_date: Date.current) }
  scope :by_client, ->(client_id) { where(client_id: client_id) }
  scope :by_service_point, ->(service_point_id) { where(service_point_id: service_point_id) }
  
  # Скоупы для работы с категориями
  scope :by_category, ->(category_id) { where(service_category_id: category_id) }
  scope :with_category, -> { includes(:service_category) }
  
  # Скоупы для динамической проверки занятости (обновлены для строковых статусов)
  scope :overlapping_time, ->(date, start_time, end_time) {
    where(booking_date: date)
      .where('start_time < ? AND end_time > ?', end_time, start_time)
      .where.not(status: CANCELLED_STATUSES.map(&:to_s))
  }
  
  scope :at_time, ->(date, time) {
    where(booking_date: date)
      .where('start_time <= ? AND end_time > ?', time, time)
      .where.not(status: CANCELLED_STATUSES.map(&:to_s))
  }
  
  # ✅ Новые скоупы для работы с гостевыми бронированиями
  scope :guest_bookings, -> { where(client_id: nil) }
  scope :client_bookings, -> { where.not(client_id: nil) }
  scope :by_guest_phone, ->(phone) { where(client_id: nil, service_recipient_phone: phone) }
  
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
  
  # Методы для работы со статусами (обновленные)
  def change_status_to!(new_status)
    if can_transition_to?(new_status)
      update!(status: new_status.to_s)
    else
      raise ArgumentError, "Невозможно изменить статус с '#{status}' на '#{new_status}'"
    end
  end
  
  def confirm!
    change_status_to!(:confirmed)
  end
  
  def start_service!
    change_status_to!(:in_progress)
  end
  
  def complete!
    change_status_to!(:completed)
  end
  
  def cancel_by_client!
    change_status_to!(:cancelled_by_client)
  end
  
  def cancel_by_partner!
    change_status_to!(:cancelled_by_partner)
  end
  
  def mark_no_show!
    change_status_to!(:no_show)
  end
  
  # Методы
  def total_duration_minutes
    return 0 unless start_time && end_time
    
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
  
  # Методы для работы с получателем услуги
  def service_recipient_full_name
    "#{service_recipient_first_name} #{service_recipient_last_name}".strip
  end
  
  def service_recipient_display_name
    service_recipient_full_name.presence || service_recipient_phone
  end
  
  # ✅ Методы для работы с гостевыми бронированиями
  def guest_booking?
    client_id.nil?
  end
  
  def client_booking?
    client_id.present?
  end
  
  def contact_name
    "#{service_recipient_first_name} #{service_recipient_last_name}".strip
  end
  
  def contact_phone
    service_recipient_phone
  end
  
  def contact_email
    service_recipient_email
  end
  
  # Проверяет, является ли получатель услуги тем же лицом, что и заказчик
  def self_service?
    return false unless client&.user
    
    client.user.first_name == service_recipient_first_name &&
    client.user.last_name == service_recipient_last_name &&
    client.user.phone == service_recipient_phone
  end
  
  # Возвращает контактную информацию для уведомлений
  def contact_info_for_notifications
    if client_booking?
      {
        recipient_name: service_recipient_full_name,
        recipient_phone: service_recipient_phone,
        recipient_email: service_recipient_email,
        booker_name: "#{client.user.first_name} #{client.user.last_name}".strip,
        booker_phone: client.user.phone,
        booker_email: client.user.email,
        is_self_service: self_service?
      }
    else
      # ✅ Для гостевых бронирований используем данные получателя услуги
      {
        recipient_name: service_recipient_full_name,
        recipient_phone: service_recipient_phone,
        recipient_email: service_recipient_email,
        booker_name: service_recipient_full_name,
        booker_phone: service_recipient_phone,
        booker_email: service_recipient_email,
        is_self_service: true,  # Для гостей всегда self-service
        is_guest_booking: true
      }
    end
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
  
  def end_time_after_start_time
    return unless start_time && end_time
    
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
  
  def car_belongs_to_client
    return unless car_id.present?
    return unless client_id.present?  # ✅ Пропускаем валидацию для гостевых бронирований
    
    unless car&.client_id == client_id
      errors.add(:car_id, "must belong to the client")
    end
  end
  
  def booking_time_available
    return if skip_availability_check
    return unless service_point_id && booking_date && start_time && end_time
    
    # Преобразуем время в правильный формат для проверки
    start_datetime = if start_time.is_a?(String)
      Time.parse("#{booking_date} #{start_time}")
    else
      Time.parse("#{booking_date} #{start_time.strftime('%H:%M')}")
    end
    
    # Проверяем что время в рабочих часах с учетом категории услуг
    availability = DynamicAvailabilityService.check_availability_at_time(
      service_point_id,
      booking_date,
      start_datetime,
      total_duration_minutes,
      exclude_booking_id: persisted? ? id : nil,
      category_id: service_category_id
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
  
  def service_category_matches_service_point
    return unless service_category_id.present? && service_point_id.present?
    
    unless service_point.supports_category?(service_category_id)
      errors.add(:service_category_id, "не поддерживается данной сервисной точкой")
    end
  end
  
  def initialize_status
    self.status = 'pending' if status.nil?
  end
  
  def send_creation_notification
    BookingNotificationJob.perform_later(id, NotificationService::NOTIFICATION_TYPES[:booking_created])
  end
  
  def send_status_change_notification
    case status
    when 'confirmed'
      BookingNotificationJob.perform_later(id, NotificationService::NOTIFICATION_TYPES[:booking_confirmed])
    when 'cancelled_by_client', 'cancelled_by_partner'
      BookingNotificationJob.perform_later(id, NotificationService::NOTIFICATION_TYPES[:booking_cancelled])
    when 'completed'
      BookingNotificationJob.perform_later(id, NotificationService::NOTIFICATION_TYPES[:booking_completed])
    end
  end
end
