FactoryBot.define do
  factory :payment_status do
    sequence(:name) { |n| "payment_status_#{n}" }
    is_active { true }
    sequence(:sort_order) { |n| n }
    
    trait :pending do
      name { 'pending' }
    end
    
    trait :paid do
      name { 'paid' }
    end
    
    trait :failed do
      name { 'failed' }
    end
    
    trait :refunded do
      name { 'refunded' }
    end
    
    trait :inactive do
      is_active { false }
    end
  end
end
