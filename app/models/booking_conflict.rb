class BookingConflict < ApplicationRecord
  belongs_to :booking
  belongs_to :resolved_by, class_name: 'User', optional: true

  # Типы конфликтов
  CONFLICT_TYPES = %w[
    schedule_change
    service_point_status
    post_status
  ].freeze

  # Типы разрешения
  RESOLUTION_TYPES = %w[
    auto_reschedule
    manual_reschedule
    cancel
    ignore
  ].freeze

  # Статусы
  STATUSES = %w[
    pending
    resolved
    ignored
  ].freeze

  # Валидации
  validates :conflict_type, presence: true, inclusion: { in: CONFLICT_TYPES }
  validates :conflict_reason, presence: true
  validates :detected_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :resolution_type, inclusion: { in: RESOLUTION_TYPES }, allow_nil: true
  validates :resolved_by, presence: true, if: -> { resolved? }
  validates :resolved_at, presence: true, if: -> { resolved? }

  # Скоупы
  scope :pending, -> { where(status: 'pending') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :ignored, -> { where(status: 'ignored') }
  scope :by_conflict_type, ->(type) { where(conflict_type: type) }
  scope :recent, -> { order(detected_at: :desc) }
  scope :for_service_point, ->(service_point_id) {
    joins(booking: :service_point).where(bookings: { service_point_id: service_point_id })
  }

  # Методы состояния
  def pending?
    status == 'pending'
  end

  def resolved?
    status == 'resolved'
  end

  def ignored?
    status == 'ignored'
  end

  # Методы разрешения конфликтов
  def resolve!(resolution_type:, resolved_by:, notes: nil)
    update!(
      status: 'resolved',
      resolution_type: resolution_type,
      resolved_by: resolved_by,
      resolved_at: Time.current,
      resolution_notes: notes
    )
  end

  def ignore!(resolved_by:, notes: nil)
    update!(
      status: 'ignored',
      resolved_by: resolved_by,
      resolved_at: Time.current,
      resolution_notes: notes
    )
  end

  # Человекочитаемые названия
  def conflict_type_human
    case conflict_type
    when 'schedule_change'
      'Изменение расписания'
    when 'service_point_status'
      'Изменение статуса сервисной точки'
    when 'post_status'
      'Изменение статуса поста'
    else
      conflict_type.humanize
    end
  end

  def resolution_type_human
    case resolution_type
    when 'auto_reschedule'
      'Автоматический перенос'
    when 'manual_reschedule'
      'Ручной перенос'
    when 'cancel'
      'Отмена'
    when 'ignore'
      'Игнорирование'
    else
      resolution_type&.humanize
    end
  end

  def status_human
    case status
    when 'pending'
      'Ожидает решения'
    when 'resolved'
      'Решен'
    when 'ignored'
      'Игнорируется'
    else
      status.humanize
    end
  end
end
