# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    association :notification_type
    recipient_type { 'User' }
    sequence(:recipient_id) { |n| n }
    sequence(:title) { |n| "Notification Title #{n}" }
    sequence(:message) { |n| "This is notification message #{n}" }
    send_via { 'push' }
    priority { 'normal' }
    category { 'general' }
    is_read { false }
    read_at { nil }
    sent_at { nil }

    transient do
      skip_broadcasts { false }
    end

    after(:build) do |notification, evaluator|
      notification.skip_broadcasts = evaluator.skip_broadcasts
    end

    trait :read do
      is_read { true }
      read_at { Time.current }
    end

    trait :unread do
      is_read { false }
      read_at { nil }
    end

    trait :sent do
      sent_at { Time.current }
    end

    trait :urgent do
      priority { 'urgent' }
    end

    trait :high_priority do
      priority { 'high' }
    end

    trait :low_priority do
      priority { 'low' }
    end

    trait :booking_category do
      category { 'booking' }
    end

    trait :system_category do
      category { 'system' }
    end

    trait :promotion_category do
      category { 'promotion' }
    end

    trait :reminder_category do
      category { 'reminder' }
    end

    trait :for_user do
      recipient_type { 'User' }
    end

    trait :for_client do
      recipient_type { 'Client' }
    end

    trait :for_partner do
      recipient_type { 'Partner' }
    end

    trait :email do
      send_via { 'email' }
    end

    trait :sms do
      send_via { 'sms' }
    end

    trait :telegram do
      send_via { 'telegram' }
    end
  end
end
