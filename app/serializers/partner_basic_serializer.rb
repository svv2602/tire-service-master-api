# Базовый сериализатор для партнеров (без избыточной информации)
class PartnerBasicSerializer
  include JSONAPI::Serializer
  
  attributes :id, :company_name, :contact_person, :is_active
  
  attribute :user_info do |partner|
    {
      id: partner.user.id,
      email: partner.user.email,
      phone: partner.user.phone,
      full_name: partner.user.full_name
    }
  end
  
  attribute :location_info do |partner|
    {
      region: partner.region&.name,
      city: partner.city&.name,
      legal_address: partner.legal_address
    }
  end
end