FactoryBot.define do
  factory :schedule_slot do
    service_point
    service_post { association :service_post, service_point: service_point, post_number: post_number }
    slot_date { Date.current + 1.day }
    start_time { Time.parse('10:00') }
    end_time { Time.parse('11:00') }
    post_number { 1 }
    is_available { true }
    
    trait :today do
      slot_date { Date.current }
    end
    
    trait :future do
      slot_date { Date.current + 7.days }
    end
    
    trait :unavailable do
      is_available { false }
    end
  end
end
