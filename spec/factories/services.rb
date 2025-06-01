FactoryBot.define do
  factory :service do
    sequence(:name) { |n| "Услуга #{n} - #{['Замена шин', 'Балансировка', 'Ремонт проколов', 'Диагностика подвески'].sample}" }
    description { Faker::Lorem.paragraph }
    default_duration { [15, 30, 45, 60, 90, 120].sample }
    sort_order { rand(0..10) }
    is_active { true }
    association :category, factory: :service_category
    
    trait :inactive do
      is_active { false }
    end
    
    trait :quick_service do
      default_duration { [15, 30].sample }
    end
    
    trait :long_service do
      default_duration { [90, 120, 180].sample }
    end
  end
end
