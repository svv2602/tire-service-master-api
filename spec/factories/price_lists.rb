FactoryBot.define do
  factory :price_list do
    name { "#{Faker::Commerce.product_name} Price List" }
    description { Faker::Lorem.paragraph }
    partner
    start_date { Date.current - 1.month }
    end_date { Date.current + 1.month }
    is_active { true }
    
    trait :global do
      service_point { nil }
    end
    
    trait :inactive do
      is_active { false }
    end
    
    trait :winter do
      season { 'winter' }
    end
    
    trait :summer do
      season { 'summer' }
    end
    
    trait :expired do
      start_date { Date.current - 2.months }
      end_date { Date.current - 1.month }
    end
    
    trait :future do
      start_date { Date.current + 1.month }
      end_date { Date.current + 2.months }
    end
  end
end
