# Сериализатор для договоренностей в админской части
class AgreementSerializer
  include JSONAPI::Serializer
  
  attributes :id, :start_date, :end_date, :commission_type, :order_types, 
             :active, :description, :created_at, :updated_at
  
  # Базовая информация о партнере
  attribute :partner_info do |agreement|
    {
      id: agreement.partner.id,
      company_name: agreement.partner.company_name,
      contact_person: agreement.partner.contact_person,
      phone: agreement.partner.phone,
      is_active: agreement.partner.is_active?
    }
  end
  
  # Базовая информация о поставщике
  attribute :supplier_info do |agreement|
    {
      id: agreement.supplier.id,
      name: agreement.supplier.name,
      firm_id: agreement.supplier.firm_id,
      is_active: agreement.supplier.is_active,
      priority: agreement.supplier.priority
    }
  end
  
  # Локализованный текст типа заказов
  attribute :order_types_text do |agreement, params|
    locale = params && params[:locale] ? params[:locale].to_sym : :ru
    agreement.order_types_text(locale)
  end
  
  # Локализованный текст активности
  attribute :active_text do |agreement, params|
    locale = params && params[:locale] ? params[:locale].to_sym : :ru
    agreement.active_text(locale)
  end
  
  # Отформатированные даты
  attribute :formatted_start_date do |agreement|
    agreement.start_date&.strftime('%d.%m.%Y')
  end
  
  attribute :formatted_end_date do |agreement|
    agreement.end_date&.strftime('%d.%m.%Y')
  end
  
  attribute :formatted_created_at do |agreement|
    agreement.created_at&.strftime('%d.%m.%Y %H:%M')
  end
  
  attribute :formatted_updated_at do |agreement|
    agreement.updated_at&.strftime('%d.%m.%Y %H:%M')
  end
  
  # Текст периода действия
  attribute :duration_text do |agreement|
    agreement.duration_text
  end
  
  # Статус договоренности
  attribute :status_text do |agreement|
    agreement.status_text
  end
  
  # Можно ли редактировать
  attribute :can_be_edited do |agreement|
    agreement.can_be_edited?
  end
  
  # Количество правил вознаграждений
  attribute :reward_rules_count do |agreement|
    agreement.reward_rules.count
  end
  
  attribute :active_reward_rules_count do |agreement|
    agreement.active_reward_rules.count
  end
  
  # Название для отображения
  attribute :display_name do |agreement|
    agreement.display_name
  end
  
  # Поддерживаемые типы заказов
  attribute :supports_cart_orders do |agreement|
    agreement.supports_cart_orders?
  end
  
  attribute :supports_pickup_orders do |agreement|
    agreement.supports_pickup_orders?
  end
end