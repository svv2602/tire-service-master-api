FactoryBot.define do
  factory :cancellation_reason do
    sequence(:name) { |n| "Cancellation Reason #{n}" }
    is_active { true }
    is_for_client { true }
    is_for_partner { false }
    sequence(:sort_order) { |n| n }
    
    trait :for_partner do
      is_for_client { false }
      is_for_partner { true }
    end
    
    trait :for_both do
      is_for_client { true }
      is_for_partner { true }
    end
    
    trait :inactive do
      is_active { false }
    end
  end
end
