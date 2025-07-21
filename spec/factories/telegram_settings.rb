FactoryBot.define do
  factory :telegram_setting do
    bot_token { "MyString" }
    webhook_url { "MyString" }
    admin_chat_id { "MyString" }
    enabled { false }
    test_mode { false }
    auto_subscription { false }
    welcome_message { "MyText" }
    help_message { "MyText" }
    error_message { "MyText" }
  end
end
