# Сериализатор для договоренностей между партнерами и поставщиками
class PartnerSupplierAgreementSerializer
  include JSONAPI::Serializer
  
  attributes :id, :start_date, :end_date, :commission_type, :active, :description,
             :created_at, :updated_at
  
  # Виртуальные атрибуты
  attribute :display_name do |agreement|
    agreement.display_name
  end
  
  attribute :duration_text do |agreement|
    agreement.duration_text
  end
  
  attribute :status_text do |agreement|
    agreement.status_text
  end
  
  attribute :current do |agreement|
    agreement.current?
  end
  
  attribute :can_be_edited do |agreement|
    agreement.can_be_edited?
  end
  
  attribute :reward_rules_count do |agreement|
    agreement.reward_rules.count
  end
  
  attribute :active_reward_rules_count do |agreement|
    agreement.active_reward_rules.count
  end
  
  # Связи не используем в этой версии сериализатора для упрощения
  
  # Условные включения связей
  attribute :partner_info, if: Proc.new { |record, params|
    params && params[:include_partner_info]
  } do |agreement|
    {
      id: agreement.partner.id,
      company_name: agreement.partner.company_name,
      contact_person: agreement.partner.contact_person,
      is_active: agreement.partner.is_active
    }
  end
  
  attribute :supplier_info, if: Proc.new { |record, params|
    params && params[:include_supplier_info]
  } do |agreement|
    {
      id: agreement.supplier.id,
      name: agreement.supplier.name,
      firm_id: agreement.supplier.firm_id,
      is_active: agreement.supplier.is_active
    }
  end
end