class OrderItemSerializer
  include JSONAPI::Serializer
  
  attributes :artikul, :quantity, :price, :sum, :bas_id, :name, :description,
             :category, :brand, :model, :attributes, :created_at, :updated_at
  
  # Связи
  belongs_to :order, serializer: OrderSerializer
  
  # Вычисляемые атрибуты
  attribute :formatted_price do |item|
    "#{item.price} ₴"
  end
  
  attribute :formatted_sum do |item|
    "#{item.sum} ₴"
  end
  
  attribute :unit_description do |item|
    case item.quantity
    when 1
      "#{item.quantity} шт."
    when 2..4
      "#{item.quantity} шт."
    else
      "#{item.quantity} шт."
    end
  end
end 