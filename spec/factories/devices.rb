FactoryBot.define do
  factory :device do
    association :user
    sequence(:device_token) { |n| "device_token_#{n}_#{SecureRandom.hex(16)}" }
    platform { 'ios' }
    device_name { 'iPhone 15 Pro' }
    device_model { 'iPhone15,2' }
    os_version { '17.4' }
    app_version { '1.0.0' }
    is_active { true }
    last_used_at { Time.current }

    trait :android do
      platform { 'android' }
      device_name { 'Samsung Galaxy S24' }
      device_model { 'SM-S921B' }
      os_version { '14' }
    end

    trait :inactive do
      is_active { false }
    end

    trait :stale do
      last_used_at { 100.days.ago }
    end
  end
end
