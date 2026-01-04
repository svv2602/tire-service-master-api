# frozen_string_literal: true

class OperatorScheduleSerializer < ActiveModel::Serializer
  attributes :id, :operator_id, :service_point_id, :schedule_date,
             :start_time, :end_time, :shift_type, :shift_type_label,
             :notes, :is_confirmed, :confirmed_by_id, :confirmed_at,
             :duration_hours, :duration_minutes,
             :created_at, :updated_at

  # Include operator details
  attribute :operator do
    return nil unless object.operator

    {
      id: object.operator.id,
      position: object.operator.position,
      is_active: object.operator.is_active,
      user: object.operator.user ? {
        id: object.operator.user.id,
        first_name: object.operator.user.first_name,
        last_name: object.operator.user.last_name,
        full_name: "#{object.operator.user.first_name} #{object.operator.user.last_name}"
      } : nil
    }
  end

  # Include service point details
  attribute :service_point do
    return nil unless object.service_point

    {
      id: object.service_point.id,
      name: object.service_point.name
    }
  end

  # Include confirmed_by user details
  attribute :confirmed_by do
    return nil unless object.confirmed_by

    {
      id: object.confirmed_by.id,
      first_name: object.confirmed_by.first_name,
      last_name: object.confirmed_by.last_name,
      full_name: "#{object.confirmed_by.first_name} #{object.confirmed_by.last_name}"
    }
  end

  def start_time
    object.start_time&.strftime('%H:%M')
  end

  def end_time
    object.end_time&.strftime('%H:%M')
  end

  def schedule_date
    object.schedule_date&.strftime('%Y-%m-%d')
  end

  def confirmed_at
    object.confirmed_at&.iso8601
  end

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end
end
