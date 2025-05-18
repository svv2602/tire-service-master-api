FactoryBot.define do
  factory :price_list_item do
    price_list
    service
    price { Faker::Commerce.price(range: 50..200) }
    
    trait :with_discount do
      discount_price { price * 0.8 } # 20% discount
    end
  end
end
