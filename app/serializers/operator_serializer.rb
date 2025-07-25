class OperatorSerializer < ActiveModel::Serializer
  attributes :id, :partner_id, :partner_name, :position, :access_level, :is_active, 
             :created_at, :updated_at, :user, :service_point_ids

  def user
    return nil unless object.user
    {
      id: object.user.id,
      first_name: object.user.first_name,
      last_name: object.user.last_name,
      full_name: "#{object.user.first_name} #{object.user.last_name}",
      email: object.user.email,
      phone: object.user.phone,
      is_active: object.user.is_active
    }
  end

  def partner_id
    object.partner_id
  end

  def partner_name
    object.partner&.name || object.partner&.company_name
  end

  def service_point_ids
    object.operator_service_points&.where(is_active: true)&.pluck(:service_point_id) || []
  end
end 