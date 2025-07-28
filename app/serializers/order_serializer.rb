class OrderSerializer
  include JSONAPI::Serializer
  
  attributes :status, :order_date, :ttn, :number, :customer_name, :customer_phone,
             :point_name, :point_id, :third_party_point, :status_kod, :bas_id,
             :separate, :ttn_status, :ttn_status_kod, :total_amount, :total_quantity,
             :processed_at, :ready_at, :delivered_at, :canceled_at, :cancellation_reason,
             :notes, :metadata, :created_at, :updated_at
  
  # Связи
  belongs_to :service_point, serializer: ServicePointSerializer
  has_many :order_items, serializer: OrderItemSerializer
  
  # Вычисляемые атрибуты
  attribute :status_label do |order|
    case order.status
    when 'received' then 'Получен'
    when 'processing' then 'В обработке'
    when 'ready' then 'Готов к выдаче'
    when 'delivered' then 'Выдан'
    when 'canceled' then 'Отменен'
    else order.status.humanize
    end
  end
  
  attribute :status_color do |order|
    case order.status
    when 'received' then '#2196F3'    # синий
    when 'processing' then '#FF9800'  # оранжевый
    when 'ready' then '#4CAF50'       # зеленый
    when 'delivered' then '#9C27B0'   # фиолетовый
    when 'canceled' then '#F44336'    # красный
    else '#757575'                    # серый
    end
  end
  
  attribute :can_mark_as_ready do |order|
    order.can_mark_as_ready?
  end
  
  attribute :can_mark_as_delivered do |order|
    order.can_mark_as_delivered?
  end
  
  attribute :can_cancel do |order|
    order.can_cancel?
  end
  
  attribute :formatted_order_date do |order|
    order.order_date&.strftime('%d.%m.%Y %H:%M')
  end
  
  attribute :formatted_phone do |order|
    # Форматирование телефона для отображения
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
end 