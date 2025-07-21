FactoryBot.define do
  factory :telegram_notification do
    message { "MyText" }
    chat_id { "MyString" }
    user { nil }
    booking { nil }
    notification_type { "MyString" }
    status { "MyString" }
    sent_at { "2025-07-20 14:18:10" }
    error_message { "MyText" }
    retry_count { 1 }
    telegram_response { "" }
    message_id { 1 }
  end
end
