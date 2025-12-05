FactoryBot.define do
  factory :service do
    sequence(:name) { |n| "Service #{n}" }
    sequence(:name_uk) { |n| "Послуга #{n}" }
    sequence(:description) { |n| "Test service description #{n}. This is a longer description for the service." }
    sequence(:description_uk) { |n| "Опис послуги #{n}. Це більш детальний опис послуги." }

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
