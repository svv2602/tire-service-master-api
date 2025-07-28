class OrderItemSerializer
  attr_reader :item
  
  def initialize(item)
    @item = item
  end
  
  def as_json
    {
      id: item.id,
      artikul: item.artikul,
      quantity: item.quantity,
      price: item.price,
      sum: item.sum,
      bas_id: item.bas_id,
      name: item.name,
      description: item.description,
      category: item.category,
      brand: item.brand,
      model: item.model,
      item_attributes: item.item_attributes,
      created_at: item.created_at,
      updated_at: item.updated_at,
      
      # Вычисляемые атрибуты
      formatted_price: "#{item.price} ₴",
      formatted_sum: "#{item.sum} ₴",
      unit_description: unit_description
    }
  end
  
  private
  
  def unit_description
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