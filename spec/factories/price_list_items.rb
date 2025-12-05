FactoryBot.define do
  factory :price_list_item do
    price_list
    service
    price { rand(50.0..200.0).round(2) }
    
    trait :with_discount do
      discount_price { price * 0.8 } # 20% discount
    end
  end
end
