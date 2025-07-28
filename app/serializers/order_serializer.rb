class OrderSerializer
  attr_reader :order
  
  def initialize(order)
    @order = order
  end
  
  def as_json
    {
      id: order.id,
      status: order.status,
      order_date: order.order_date,
      ttn: order.ttn,
      number: order.number,
      customer_name: order.customer_name,
      customer_phone: order.customer_phone,
      point_name: order.point_name,
      point_id: order.point_id,
      third_party_point: order.third_party_point,
      status_kod: order.status_kod,
      bas_id: order.bas_id,
      separate: order.separate,
      ttn_status: order.ttn_status,
      ttn_status_kod: order.ttn_status_kod,
      total_amount: order.total_amount,
      total_quantity: order.total_quantity,
      processed_at: order.processed_at,
      ready_at: order.ready_at,
      delivered_at: order.delivered_at,
      canceled_at: order.canceled_at,
      cancellation_reason: order.cancellation_reason,
      notes: order.notes,
      metadata: order.metadata,
      created_at: order.created_at,
      updated_at: order.updated_at,
      
      # Вычисляемые атрибуты
      status_label: status_label,
      status_color: status_color,
      can_mark_as_ready: order.can_mark_as_ready?,
      can_mark_as_delivered: order.can_mark_as_delivered?,
      can_cancel: order.can_cancel?,
      formatted_order_date: order.order_date&.strftime('%d.%m.%Y %H:%M'),
      formatted_phone: formatted_phone,
      
      # Информация о сервисной точке
      service_point_name: order.service_point&.name,
      service_point_city: order.service_point&.city&.name,
      service_point_address: order.service_point&.address,
      
      # Количество товаров
      items_count: order.order_items.count,
      items_summary: items_summary,
      
      # Товары заказа
      order_items: order.order_items.map { |item| OrderItemSerializer.new(item).as_json }
    }
  end
  
  private
  
  def status_label
    case order.status
    when 'received' then 'Получен'
    when 'processing' then 'В обработке'
    when 'ready' then 'Готов к выдаче'
    when 'delivered' then 'Выдан'
    when 'canceled' then 'Отменен'
    else order.status.humanize
    end
  end
  
  def status_color
    case order.status
    when 'received' then '#2196F3'    # синий
    when 'processing' then '#FF9800'  # оранжевый
    when 'ready' then '#4CAF50'       # зеленый
    when 'delivered' then '#9C27B0'   # фиолетовый
    when 'canceled' then '#F44336'    # красный
    else '#757575'                    # серый
    end
  end
  
  def formatted_phone
    phone = order.customer_phone
    return phone unless phone.present?
    
    # Убираем все символы кроме цифр
    digits = phone.gsub(/\D/, '')
    
    # Форматируем в украинский формат
    if digits.length == 12 && digits.start_with?('380')
      "+38 (#{digits[3..5]}) #{digits[6..8]}-#{digits[9..10]}-#{digits[11..12]}"
    else
      phone
    end
  end
  
  def items_summary
    order.order_items.limit(3).map do |item|
      "#{item.name} (#{item.quantity} шт.)"
    end.join(', ') + (order.order_items.count > 3 ? '...' : '')
  end
end 