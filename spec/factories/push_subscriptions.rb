FactoryBot.define do
  factory :push_subscription do
    user { nil }
    endpoint { "MyText" }
    p256dh_key { "MyText" }
    auth_key { "MyText" }
    user_agent { "MyText" }
    is_active { false }
    last_used_at { "2025-07-22 15:37:11" }
  end
end
