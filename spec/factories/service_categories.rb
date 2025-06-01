FactoryBot.define do
  factory :service_category do
    sequence(:name) { |n| "Category #{n} - #{['Шиномонтаж', 'Диагностика', 'Ремонт тормозов', 'Замена масла'].sample}" }
    description { Faker::Lorem.sentence }
    is_active { true }
    sort_order { rand(0..10) }
    
    trait :inactive do
      is_active { false }
    end
    
    trait :with_services do
      after(:create) do |category|
        create_list(:service, 3, category: category)
      end
    end
  end
end
