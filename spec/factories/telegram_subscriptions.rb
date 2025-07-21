FactoryBot.define do
  factory :telegram_subscription do
    chat_id { "MyString" }
    user { nil }
    is_active { false }
    username { "MyString" }
    first_name { "MyString" }
    last_name { "MyString" }
    language_code { "MyString" }
    notification_preferences { "MyText" }
    last_interaction_at { "2025-07-20 14:17:55" }
    status { "MyString" }
  end
end
