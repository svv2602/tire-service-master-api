FactoryBot.define do
  factory :review do
    association :service_point
    association :booking
    association :client
    rating { rand(1..5) }
    sequence(:comment) { |n| "Test review comment #{n}. This is a longer comment for the review." }
    is_published { true }

    # AI moderation fields
    moderation_status { nil }
    moderation_reason { nil }
    moderation_confidence { nil }
    ai_sentiment { nil }
    ai_classification { nil }
    ai_suggested_reply { nil }
    ai_is_fake { false }
    ai_metadata { {} }

    trait :unpublished do
      is_published { false }
    end

    trait :with_photos do
      after(:create) do |review|
        create_list(:review_photo, 2, review: review)
      end
    end

    trait :with_low_rating do
      rating { 1 }
    end

    trait :with_high_rating do
      rating { 5 }
    end

    trait :ai_approved do
      moderation_status { 'approved' }
      moderation_confidence { 0.95 }
      ai_classification { 'positive' }
      ai_sentiment { 'positive' }
    end

    trait :ai_flagged do
      moderation_status { 'flagged' }
      moderation_confidence { 0.5 }
      ai_classification { 'neutral' }
      ai_sentiment { 'neutral' }
    end

    trait :ai_rejected do
      moderation_status { 'rejected' }
      moderation_confidence { 0.95 }
      ai_classification { 'spam' }
    end
  end
end
