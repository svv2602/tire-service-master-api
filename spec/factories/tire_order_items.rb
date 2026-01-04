FactoryBot.define do
  factory :tire_order_item do
    tire_order
    supplier_tire_product
    quantity { 4 }
    price_at_order { 4500.00 }
  end
end
