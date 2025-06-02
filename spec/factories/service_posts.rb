FactoryBot.define do
  factory :service_post do
    association :service_point
    sequence(:post_number) { |n| n }
    name { "Пост #{post_number}" }
    slot_duration { 60 }
    is_active { true }
    description { "Пост обслуживания №#{post_number}" }
    
    trait :inactive do
      is_active { false }
    end
    
    trait :short_duration do
      slot_duration { 30 }
    end
    
    trait :long_duration do
      slot_duration { 120 }
    end
  end
end
