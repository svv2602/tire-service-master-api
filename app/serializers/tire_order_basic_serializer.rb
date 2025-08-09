# Базовый сериализатор для заказов через корзину (без избыточной информации)
class TireOrderBasicSerializer
  include JSONAPI::Serializer
  
  attributes :id, :status, :total_amount, :client_name, :client_phone,
             :created_at, :updated_at
  
  attribute :status_display do |tire_order|
    tire_order.status_display
  end
  
  attribute :formatted_total do |tire_order|
    tire_order.formatted_total
  end
  
  attribute :items_count do |tire_order|
    tire_order.items_count
  end
  
  attribute :order_info do |tire_order|
    {
      type: 'tire_order',
      display_name: "Заказ №#{tire_order.id}",
      created_date: tire_order.created_at.strftime('%d.%m.%Y'),
      status_color: status_color(tire_order.status)
    }
  end
  
  private
  
  def self.status_color(status)
    case status
    when 'draft'
      '#6b7280' # Gray
    when 'submitted'
      '#f59e0b' # Amber
    when 'confirmed'
      '#3b82f6' # Blue
    when 'processing'
      '#8b5cf6' # Purple
    when 'completed'
      '#10b981' # Emerald
    when 'cancelled'
      '#ef4444' # Red
    when 'archived'
      '#6b7280' # Gray
    else
      '#6b7280' # Gray
    end
  end
end