# Базовый сериализатор для заказов интернет-магазинов (без избыточной информации)
class OrderBasicSerializer
  include JSONAPI::Serializer
  
  attributes :id, :ttn, :status, :total_amount, :total_quantity,
             :customer_name, :customer_phone, :order_date
  
  attribute :status_display do |order|
    case order.status
    when 'received'
      'Получен'
    when 'processing'
      'В обработке'
    when 'ready'
      'Готов к выдаче'
    when 'delivered'
      'Выдан'
    when 'canceled'
      'Отменен'
    else
      order.status
    end
  end
  
  attribute :formatted_total_amount do |order|
    "#{order.total_amount.to_f} ₴"
  end
  
  attribute :order_info do |order|
    {
      type: 'order',
      display_name: "ТТН #{order.ttn}",
      order_date: order.order_date.strftime('%d.%m.%Y'),
      status_color: status_color(order.status)
    }
  end
  
  attribute :service_point_info do |order|
    {
      id: order.service_point.id,
      name: order.service_point.name,
      address: order.service_point.address,
      partner_name: order.service_point.partner.company_name
    }
  end
  
  private
  
  def self.status_color(status)
    case status
    when 'received'
      '#f59e0b' # Amber
    when 'processing'
      '#3b82f6' # Blue
    when 'ready'
      '#8b5cf6' # Purple
    when 'delivered'
      '#10b981' # Emerald
    when 'canceled'
      '#ef4444' # Red
    else
      '#6b7280' # Gray
    end
  end
end