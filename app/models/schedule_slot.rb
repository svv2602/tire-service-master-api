class ScheduleSlot < ApplicationRecord
  # Reservation statuses
  RESERVATION_STATUSES = %w[available reserved confirmed expired].freeze
  RESERVATION_TIMEOUT_MINUTES = 10

  # Связи
  belongs_to :service_point
  belongs_to :service_post

  # Валидации
  validates :slot_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :post_number, presence: true, numericality: { greater_than: 0 }
  validates :service_point_id, uniqueness: { scope: [:slot_date, :start_time, :post_number] }
  validates :reservation_status, inclusion: { in: RESERVATION_STATUSES }, allow_nil: true
  validate :end_time_after_start_time
  validate :service_post_belongs_to_service_point

  # Скоупы
  scope :available, -> { where(is_available: true) }
  scope :upcoming, -> { where('slot_date >= ?', Date.current) }
  scope :today, -> { where(slot_date: Date.current) }
  scope :future, -> { where('slot_date > ?', Date.current) }
  scope :by_date_range, ->(start_date, end_date) {
    where('slot_date >= ? AND slot_date <= ?', start_date, end_date)
  }
  scope :for_time_range, ->(start_time, end_time) {
    where('start_time >= ? AND end_time <= ?', start_time, end_time)
  }
  scope :for_service_post, ->(service_post_id) { where(service_post_id: service_post_id) }

  # Reservation scopes
  scope :not_reserved, -> { where(reservation_status: [nil, 'available', 'expired']) }
  scope :reserved, -> { where(reservation_status: 'reserved') }
  scope :with_expired_reservations, -> { where('reserved_until < ?', Time.current).where(reservation_status: 'reserved') }
  scope :reserved_by_session, ->(session_id) { where(reserved_by_session: session_id, reservation_status: 'reserved') }
  
  # Методы
  def duration_in_minutes
    minutes_start = start_time.hour * 60 + start_time.min
    minutes_end = end_time.hour * 60 + end_time.min
    minutes_end - minutes_start
  end
  
  # Проверка занятости теперь не актуальна, но оставляем для совместимости со старым кодом
  def booked?
    false # В динамической системе слоты не бронируются напрямую
  end
  
  # Получает длительность слота из настроек поста
  def configured_duration_in_minutes
    service_post&.slot_duration || duration_in_minutes
  end

  # ==================== RESERVATION METHODS ====================

  # Temporarily reserve slot for a session
  # @param session_id [String] unique session identifier
  # @param timeout_minutes [Integer] reservation timeout in minutes
  # @return [Boolean] true if reservation successful
  def reserve!(session_id, timeout_minutes: RESERVATION_TIMEOUT_MINUTES)
    return false unless can_be_reserved?

    transaction do
      # Lock the record to prevent race conditions
      lock!

      # Double-check availability after lock
      return false unless can_be_reserved?

      update!(
        reservation_status: 'reserved',
        reserved_at: Time.current,
        reserved_until: Time.current + timeout_minutes.minutes,
        reserved_by_session: session_id
      )
    end

    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
    false
  end

  # Release reservation
  # @param session_id [String] session that made the reservation (optional verification)
  # @return [Boolean] true if released
  def release!(session_id = nil)
    return false if session_id.present? && reserved_by_session != session_id

    update!(
      reservation_status: 'available',
      reserved_at: nil,
      reserved_until: nil,
      reserved_by_session: nil
    )

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Confirm reservation (convert to permanent booking)
  # @return [Boolean] true if confirmed
  def confirm!
    return false unless reservation_status == 'reserved'

    update!(reservation_status: 'confirmed')
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Check if slot can be reserved
  # @return [Boolean]
  def can_be_reserved?
    return false unless is_available?
    return true if reservation_status.blank? || reservation_status == 'available'
    return true if reservation_status == 'expired'
    return true if reservation_expired?

    false
  end

  # Check if reservation has expired
  # @return [Boolean]
  def reservation_expired?
    return false unless reserved_until.present?

    reserved_until < Time.current
  end

  # Check if slot is currently reserved
  # @return [Boolean]
  def reserved?
    reservation_status == 'reserved' && !reservation_expired?
  end

  # Check if slot is reserved by specific session
  # @param session_id [String]
  # @return [Boolean]
  def reserved_by?(session_id)
    reserved? && reserved_by_session == session_id
  end

  # Get remaining reservation time in seconds
  # @return [Integer, nil]
  def reservation_remaining_seconds
    return nil unless reserved? && reserved_until.present?

    remaining = (reserved_until - Time.current).to_i
    remaining.positive? ? remaining : 0
  end

  # Expire reservation if timeout reached
  # @return [Boolean] true if expired
  def expire_if_timeout!
    return false unless reservation_expired? && reservation_status == 'reserved'

    update!(reservation_status: 'expired')
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Class method to cleanup expired reservations
  def self.cleanup_expired_reservations
    with_expired_reservations.find_each do |slot|
      slot.expire_if_timeout!
      Rails.logger.info "[ScheduleSlot] Expired reservation for slot #{slot.id}"
    end
  end

  private
  
  def end_time_after_start_time
    return unless start_time && end_time
    
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
  
  def service_post_belongs_to_service_point
    return unless service_post && service_point
    
    if service_post.service_point_id != service_point_id
      errors.add(:service_post, "must belong to the same service point")
    end
  end
end
