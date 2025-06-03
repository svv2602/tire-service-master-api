FactoryBot.define do
  factory :service_point do
    sequence(:name) { |n| "Service Point #{n}-#{Time.now.to_f}-#{SecureRandom.hex(4)}" }
    address { Faker::Address.full_address }
    latitude { Faker::Address.latitude }
    longitude { Faker::Address.longitude }
    contact_phone { Faker::PhoneNumber.cell_phone_in_e164 }
    description { Faker::Lorem.paragraph }
    post_count { rand(1..5) }
    default_slot_duration { 30 }
    is_active { true }
    work_status { 'working' }
    partner
    city
    total_clients_served { 0 }
    average_rating { 0.0 }
    cancellation_rate { 0.0 }
    
    trait :with_amenities do
      transient do
        amenities_count { 3 }
      end
      
      after(:create) do |service_point, evaluator|
        create_list(:service_point_amenity, evaluator.amenities_count, service_point: service_point)
      end
    end
    
    trait :with_photos do
      transient do
        photos_count { 3 }
      end
      
      after(:create) do |service_point, evaluator|
        create_list(:service_point_photo, evaluator.photos_count, service_point: service_point)
      end
    end
    
    trait :with_reviews do
      transient do
        reviews_count { 3 }
        average_rating { 4.0 }
      end
      
      after(:create) do |service_point, evaluator|
        create_list(:review, evaluator.reviews_count, service_point: service_point, rating: evaluator.average_rating)
      end
    end
    
    trait :with_schedule do
      after(:create) do |service_point|
        create(:schedule_template, service_point: service_point)
      end
    end
  end
end
