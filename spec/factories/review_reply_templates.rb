FactoryBot.define do
  factory :review_reply_template do
    sequence(:name) { |n| "Reply Template #{n}" }
    content { 'Thank you for your feedback!' }
    category { 'general' }
    is_active { true }
    sort_order { 0 }
    usage_count { 0 }
    partner { nil }

    trait :positive do
      category { 'positive' }
      content { 'Thank you for the wonderful review! We appreciate your feedback.' }
    end

    trait :negative do
      category { 'apology' }
      content { 'We apologize for your experience. Please contact us to resolve this.' }
    end

    trait :for_partner do
      association :partner
    end

    trait :inactive do
      is_active { false }
    end
  end
end
