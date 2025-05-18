FactoryBot.define do
  factory :booking_service do
    booking
    service
    quantity { 1 }
    price { rand(100..1000) }
    
    trait :multiple_quantity do
      quantity { rand(2..5) }
    end
  end
end
