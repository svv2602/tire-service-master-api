class OperatorSerializer < ActiveModel::Serializer
  attributes :id, :position, :access_level, :is_active, :created_at, :updated_at, :user, :partner

  def user
    return nil unless object.user
    {
      id: object.user.id,
      first_name: object.user.first_name,
      last_name: object.user.last_name,
      email: object.user.email,
      phone: object.user.phone,
      is_active: object.user.is_active
    }
  end

  def partner
    return nil unless object.partner
    {
      id: object.partner.id,
      company_name: object.partner.company_name
    }
  end
end 