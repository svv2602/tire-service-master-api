FactoryBot.define do
  factory :telegram_setting do
    bot_token { "123456789:ABCDEFghijklmnopqrstuvwxyz" }
    webhook_url { "https://example.com/telegram/webhook" }
    admin_chat_id { "123456789" }
    enabled { true }
    test_mode { false }
    auto_subscription { true }
    welcome_message { "Welcome to Tire Service bot!" }
    help_message { "Available commands: /start, /help, /booking, /status" }
    error_message { "An error occurred. Please try again." }

    trait :disabled do
      enabled { false }
    end

    trait :test_mode do
      test_mode { true }
    end

    trait :without_webhook do
      webhook_url { nil }
    end

    trait :without_token do
      bot_token { nil }
    end
  end
end
