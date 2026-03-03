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
      
      # Service point info (uses preloaded association via includes)
      service_point_name: cached_service_point&.name,
      service_point_city: cached_service_point&.city&.name,
      service_point_address: cached_service_point&.address,

      # Supplier info (uses preloaded association via includes)
      supplier_name: order.supplier&.name,
      supplier_firm_id: order.supplier&.firm_id,

      # Items count — .size uses preloaded collection, .count always hits DB
      items_count: order.order_items.size,
      items_summary: items_summary,

      # Order items (reuse the already-loaded collection)
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
    items = order.order_items
    items.first(3).map do |item|
      "#{item.name} (#{item.quantity} шт.)"
    end.join(', ') + (items.size > 3 ? '...' : '')
  end

  def cached_service_point
    @cached_service_point ||= order.service_point
  end
end 