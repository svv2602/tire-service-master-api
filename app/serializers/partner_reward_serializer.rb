# Сериализатор для вознаграждений партнеров
class PartnerRewardSerializer
  include JSONAPI::Serializer
  
  attributes :id, :calculated_amount, :payment_status, :calculated_at, 
             :paid_at, :notes, :created_at, :updated_at
  
  # Виртуальные атрибуты
  attribute :payment_status_display do |reward|
    reward.payment_status_display
  end
  
  attribute :formatted_amount do |reward|
    reward.formatted_amount
  end
  
  attribute :formatted_calculated_at do |reward|
    reward.formatted_calculated_at
  end
  
  attribute :formatted_paid_at do |reward|
    reward.formatted_paid_at
  end
  
  attribute :order_type do |reward|
    reward.order_type
  end
  
  attribute :order_number do |reward|
    reward.order_number
  end
  
  attribute :order_amount do |reward|
    reward.order_amount
  end
  
  attribute :order_date do |reward|
    reward.order_date.strftime('%d.%m.%Y %H:%M')
  end
  
  attribute :can_be_marked_as_paid do |reward|
    reward.can_be_marked_as_paid?
  end
  
  attribute :can_be_cancelled do |reward|
    reward.can_be_cancelled?
  end
  
  # Флаги статусов
  attribute :is_pending do |reward|
    reward.pending?
  end
  
  attribute :is_paid do |reward|
    reward.paid?
  end
  
  attribute :is_cancelled do |reward|
    reward.cancelled?
  end
  
  # Связи не используем в этой версии сериализатора для упрощения
  
  # Информация о партнере
  attribute :partner_info, if: Proc.new { |record, params|
    params && params[:include_partner_info]
  } do |reward|
    partner = reward.partner
    {
      id: partner.id,
      company_name: partner.company_name,
      contact_person: partner.contact_person,
      phone: partner.user.phone,
      email: partner.user.email
    }
  end
  
  # Информация о поставщике
  attribute :supplier_info, if: Proc.new { |record, params|
    params && params[:include_supplier_info]
  } do |reward|
    supplier = reward.supplier
    {
      id: supplier.id,
      name: supplier.name,
      firm_id: supplier.firm_id,
      is_active: supplier.is_active
    }
  end
  
  # Информация о правиле вознаграждения
  attribute :rule_info, if: Proc.new { |record, params|
    params && params[:include_rule_info]
  } do |reward|
    rule = reward.reward_rule
    {
      id: rule.id,
      rule_type: rule.rule_type,
      rule_type_display: rule.rule_type_display,
      amount: rule.amount,
      amount_display: rule.amount_display,
      conditions_description: rule.conditions_description,
      priority: rule.priority
    }
  end
  
  # Детальная информация о заказе
  attribute :order_details, if: Proc.new { |record, params|
    params && params[:include_order_details]
  } do |reward|
    order_ref = reward.order_reference
    return nil unless order_ref
    
    if order_ref.is_a?(TireOrder)
      {
        type: 'tire_order',
        id: order_ref.id,
        status: order_ref.status,
        status_display: order_ref.status_display,
        total_amount: order_ref.total_amount,
        items_count: order_ref.items_count,
        client_name: order_ref.client_name,
        client_phone: order_ref.client_phone,
        created_at: order_ref.created_at.strftime('%d.%m.%Y %H:%M'),
        updated_at: order_ref.updated_at.strftime('%d.%m.%Y %H:%M')
      }
    elsif order_ref.is_a?(Order)
      {
        type: 'order',
        id: order_ref.id,
        ttn: order_ref.ttn,
        status: order_ref.status,
        total_amount: order_ref.total_amount,
        total_quantity: order_ref.total_quantity,
        customer_name: order_ref.customer_name,
        customer_phone: order_ref.customer_phone,
        order_date: order_ref.order_date.strftime('%d.%m.%Y'),
        service_point_name: order_ref.service_point.name
      }
    end
  end
  
  # Цветовая схема для UI
  attribute :ui_color_scheme do |reward|
    case reward.payment_status
    when 'pending'
      { primary: '#f59e0b', secondary: '#fef3c7', text: '#92400e' } # Amber
    when 'paid'
      { primary: '#10b981', secondary: '#d1fae5', text: '#065f46' } # Emerald
    when 'cancelled'
      { primary: '#ef4444', secondary: '#fecaca', text: '#991b1b' } # Red
    else
      { primary: '#6b7280', secondary: '#f3f4f6', text: '#374151' } # Gray
    end
  end
end