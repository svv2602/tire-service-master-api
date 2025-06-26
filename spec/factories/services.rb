FactoryBot.define do
  factory :service do
    sequence(:name) { |n| "Услуга #{n} - #{['Замена шин', 'Балансировка', 'Ремонт проколов', 'Диагностика подвески'].sample}" }
    description { Faker::Lorem.paragraph }

    sort_order { rand(0..10) }
    is_active { true }
    association :category, factory: :service_category
    
    trait :inactive do
      is_active { false }
    end
    
    trait :quick_service do
  
    end
    
    trait :long_service do
  
    end
  end
end
