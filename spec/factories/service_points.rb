FactoryBot.define do
  factory :service_point do
    sequence(:name) { |n| "Service Point #{n}-#{Time.now.to_f}-#{SecureRandom.hex(4)}" }
    address { Faker::Address.full_address }
    latitude { Faker::Address.latitude }
    longitude { Faker::Address.longitude }
    contact_phone { Faker::PhoneNumber.cell_phone_in_e164 }
    description { Faker::Lorem.paragraph }
    is_active { true }
    work_status { 'working' }
    partner { association :partner, :with_new_user }
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
        # Создаем расписание для всех дней недели
        (1..7).each do |sort_order|
          weekday = Weekday.find_or_create_by!(sort_order: sort_order) do |w|
            w.name = Date::DAYNAMES[sort_order % 7]
            w.short_name = Date::ABBR_DAYNAMES[sort_order % 7]
          end
          
          create(:schedule_template, 
                 service_point: service_point, 
                 weekday: weekday,
                 is_working_day: true,
                 opening_time: '09:00:00',
                 closing_time: '18:00:00')
        end
      end
    end
  end
end
