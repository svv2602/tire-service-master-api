FactoryBot.define do
  factory :telegram_subscription do
    sequence(:chat_id) { |n| "#{100000000 + n}" }
    association :user
    is_active { true }
    sequence(:username) { |n| "test_user_#{n}" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    language_code { "uk" }
    notification_preferences { { bookings: true, promotions: true, reminders: true }.to_json }
    last_interaction_at { Time.current }
    status { "active" }
    sent_notifications_count { 0 }

    trait :inactive do
      is_active { false }
      status { "inactive" }
    end

    trait :with_notifications do
      sent_notifications_count { 10 }
    end

    transient do
      can_receive { true }
    end

    after(:build) do |subscription, evaluator|
      if evaluator.can_receive
        subscription.define_singleton_method(:can_receive_notifications?) { true }
      else
        subscription.define_singleton_method(:can_receive_notifications?) { false }
      end
    end
  end
end
