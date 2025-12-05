FactoryBot.define do
  factory :telegram_notification do
    message { "Test notification message" }
    sequence(:chat_id) { |n| "#{100000000 + n}" }
    association :user
    booking { nil }
    notification_type { "general" }
    status { "pending" }
    sent_at { nil }
    error_message { nil }
    retry_count { 0 }
    telegram_response { nil }
    message_id { nil }

    trait :sent do
      status { "sent" }
      sent_at { Time.current }
      sequence(:message_id) { |n| n }
      telegram_response { { ok: true, result: { message_id: 1 } }.to_json }
    end

    trait :failed do
      status { "failed" }
      error_message { "Failed to send message" }
      retry_count { 1 }
    end

    trait :booking_notification do
      notification_type { "booking" }
      association :booking
    end

    trait :promotion_notification do
      notification_type { "promotion" }
    end

    trait :reminder_notification do
      notification_type { "reminder" }
    end

    trait :system_notification do
      notification_type { "system" }
    end

    trait :max_retries do
      status { "failed" }
      retry_count { 3 }
    end
  end
end
