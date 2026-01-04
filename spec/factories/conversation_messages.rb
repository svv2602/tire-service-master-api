# frozen_string_literal: true

FactoryBot.define do
  factory :conversation_message do
    association :conversation
    role { 'user' }
    content { 'Test message' }
    metadata { {} }

    trait :user do
      role { 'user' }
      content { 'I need help with tires' }
    end

    trait :assistant do
      role { 'assistant' }
      content { 'I can help you find the perfect tires!' }
    end

    trait :system do
      role { 'system' }
      content { 'System instruction' }
    end

    trait :with_products do
      role { 'assistant' }
      metadata do
        {
          'products' => [
            { id: 1, name: 'Michelin Pilot Sport 4', price: 5000 },
            { id: 2, name: 'Continental PremiumContact 6', price: 4500 }
          ]
        }
      end
    end

    trait :with_search_params do
      metadata do
        {
          'search_params' => {
            width: 205,
            profile: 55,
            diameter: 16,
            season: 'summer'
          }
        }
      end
    end
  end
end
