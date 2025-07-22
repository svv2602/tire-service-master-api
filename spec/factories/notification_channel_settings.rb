FactoryBot.define do
  factory :notification_channel_setting do
    channel_type { "MyString" }
    enabled { false }
    priority { 1 }
    retry_attempts { 1 }
    retry_delay { 1 }
    daily_limit { 1 }
    rate_limit_per_minute { 1 }
  end
end
