FactoryBot.define do
  factory :review do
    association :service_point
    association :booking
    association :client
    rating { rand(1..5) }
    comment { Faker::Lorem.paragraph }
    is_published { true }
    
    trait :unpublished do
      is_published { false }
    end
    
    trait :with_photos do
      after(:create) do |review|
        create_list(:review_photo, 2, review: review)
      end
    end
    
    trait :with_low_rating do
      rating { 1 }
    end
    
    trait :with_high_rating do
      rating { 5 }
    end
  end
end
