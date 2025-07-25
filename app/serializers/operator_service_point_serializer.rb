class OperatorServicePointSerializer < ActiveModel::Serializer
  attributes :id, :operator_id, :service_point_id, :is_active, :assigned_at, :created_at, :updated_at
  
  # Информация об операторе
  attribute :operator_info
  
  # Информация о сервисной точке
  attribute :service_point_info
  
  # Информация о партнере
  attribute :partner_info

  def operator_info
    {
      id: object.operator.id,
      user_id: object.operator.user_id,
      first_name: object.operator.user.first_name,
      last_name: object.operator.user.last_name,
      full_name: object.operator.user.full_name,
      email: object.operator.user.email,
      phone: object.operator.user.phone,
      is_active: object.operator.is_active
    }
  end

  def service_point_info
    {
      id: object.service_point.id,
      name: object.service_point.name,
      address: object.service_point.address,
      city_id: object.service_point.city_id,
      city_name: object.service_point.city.name,
      region_name: object.service_point.city.region.name,
      phone: object.service_point.phone,
      work_status: object.service_point.work_status,
      is_active: object.service_point.is_active
    }
  end

  def partner_info
    {
      id: object.service_point.partner.id,
      name: object.service_point.partner.name,
      email: object.service_point.partner.user.email,
      phone: object.service_point.partner.user.phone
    }
  end

  def assigned_at
    object.assigned_at&.iso8601
  end

  def created_at
    object.created_at.iso8601
  end

  def updated_at
    object.updated_at.iso8601
  end
end 