FactoryBot.define do
  factory :review do
    association :booking, factory: [:booking, :completed]
    client { booking.client }
    service_point { booking.service_point }
    rating { rand(1..5) }
    comment { Faker::Lorem.paragraph }
    is_published { true }
    
    trait :unpublished do
      is_published { false }
    end
    
    trait :with_low_rating do
      rating { 1 }
    end
    
    trait :with_high_rating do
      rating { 5 }
    end
  end
end
