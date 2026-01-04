# frozen_string_literal: true

class OperatorSchedule < ApplicationRecord
  # Associations
  belongs_to :operator
  belongs_to :service_point
  belongs_to :confirmed_by, class_name: 'User', optional: true

  # Validations
  validates :schedule_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :shift_type, presence: true, inclusion: { in: %w[regular overtime replacement] }

  validate :end_time_after_start_time
  validate :no_overlapping_schedules
  validate :operator_belongs_to_service_point

  # Scopes
  scope :for_date, ->(date) { where(schedule_date: date) }
  scope :for_date_range, ->(start_date, end_date) { where(schedule_date: start_date..end_date) }
  scope :for_operator, ->(operator_id) { where(operator_id: operator_id) }
  scope :for_service_point, ->(service_point_id) { where(service_point_id: service_point_id) }
  scope :confirmed, -> { where(is_confirmed: true) }
  scope :unconfirmed, -> { where(is_confirmed: false) }
  scope :by_shift_type, ->(type) { where(shift_type: type) }
  scope :upcoming, -> { where('schedule_date >= ?', Date.current) }
  scope :past, -> { where('schedule_date < ?', Date.current) }
  scope :today, -> { where(schedule_date: Date.current) }
  scope :this_week, -> { where(schedule_date: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :this_month, -> { where(schedule_date: Date.current.beginning_of_month..Date.current.end_of_month) }

  # Callbacks
  before_save :set_confirmed_at, if: :is_confirmed_changed?

  # Instance methods
  def confirm!(user)
    update!(
      is_confirmed: true,
      confirmed_by: user,
      confirmed_at: Time.current
    )
  end

  def unconfirm!
    update!(
      is_confirmed: false,
      confirmed_by: nil,
      confirmed_at: nil
    )
  end

  def duration_hours
    return 0 unless start_time && end_time

    ((end_time - start_time) / 1.hour).round(2)
  end

  def duration_minutes
    return 0 unless start_time && end_time

    ((end_time - start_time) / 1.minute).to_i
  end

  def shift_type_label
    case shift_type
    when 'regular' then 'Обычная смена'
    when 'overtime' then 'Сверхурочная'
    when 'replacement' then 'Замена'
    else shift_type
    end
  end

  def overlaps_with?(other_schedule)
    return false if other_schedule.id == id
    return false if schedule_date != other_schedule.schedule_date

    start_time < other_schedule.end_time && end_time > other_schedule.start_time
  end

  def covers_time?(time)
    time_only = time.is_a?(Time) ? time.strftime('%H:%M:%S') : time.to_s
    start_str = start_time.strftime('%H:%M:%S')
    end_str = end_time.strftime('%H:%M:%S')

    time_only >= start_str && time_only < end_str
  end

  # Class methods
  class << self
    def total_hours_for_operator(operator_id, start_date, end_date)
      for_operator(operator_id)
        .for_date_range(start_date, end_date)
        .sum { |schedule| schedule.duration_hours }
    end

    def operators_available_at(service_point_id, date, time)
      for_service_point(service_point_id)
        .for_date(date)
        .confirmed
        .select { |schedule| schedule.covers_time?(time) }
        .map(&:operator)
    end

    def load_for_date(service_point_id, date)
      schedules = for_service_point(service_point_id).for_date(date).confirmed
      return 0 if schedules.empty?

      total_operator_hours = schedules.sum(&:duration_hours)
      # Assuming 8-hour standard workday for load calculation
      max_capacity = schedules.count * 8.0

      [(total_operator_hours / max_capacity * 100).round, 100].min
    end
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time

    if end_time <= start_time
      errors.add(:end_time, 'должно быть позже времени начала')
    end
  end

  def no_overlapping_schedules
    return unless operator_id && schedule_date && start_time && end_time

    overlapping = OperatorSchedule
                    .where(operator_id: operator_id, schedule_date: schedule_date)
                    .where.not(id: id)
                    .where('start_time < ? AND end_time > ?', end_time, start_time)

    if overlapping.exists?
      errors.add(:base, 'Расписание пересекается с существующим')
    end
  end

  def operator_belongs_to_service_point
    return unless operator_id && service_point_id

    unless operator.service_points.exists?(id: service_point_id)
      errors.add(:operator, 'не привязан к данной сервисной точке')
    end
  end

  def set_confirmed_at
    if is_confirmed
      self.confirmed_at ||= Time.current
    else
      self.confirmed_at = nil
      self.confirmed_by = nil
    end
  end
end
