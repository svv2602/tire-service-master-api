# frozen_string_literal: true

FactoryBot.define do
  factory :chat_analytic do
    session_id { "session_#{SecureRandom.hex(8)}" }
    user_query { 'зимние шины 205/55R16' }
    normalized_query { 'зимние шины 205 55 r16' }
    response_type { 'product_recommendation' }
    intent { 'winter_tires' }
    products_shown { [] }
    products_count { 0 }
    response_time_ms { rand(100..500) }
    had_results { true }
    is_quick_question { false }
    is_brand_comparison { false }
    filters_used { {} }
    metadata { {} }

    trait :with_results do
      had_results { true }
      products_count { rand(1..10) }
      products_shown { [1, 2, 3] }
    end

    trait :without_results do
      had_results { false }
      products_count { 0 }
      products_shown { [] }
    end

    trait :quick_question do
      is_quick_question { true }
    end

    trait :brand_comparison do
      is_brand_comparison { true }
      response_type { 'brand_comparison' }
      intent { 'brand_comparison' }
    end

    trait :with_conversation do
      association :conversation
    end

    trait :winter_search do
      user_query { 'шины для зимы' }
      normalized_query { 'шины для зимы' }
      intent { 'winter_tires' }
    end

    trait :summer_search do
      user_query { 'летние шины' }
      normalized_query { 'летние шины' }
      intent { 'summer_tires' }
    end

    trait :size_selection do
      user_query { '205/55R16' }
      normalized_query { '205 55 r16' }
      intent { 'size_selection' }
      response_type { 'size_selection' }
    end
  end
end
