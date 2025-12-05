FactoryBot.define do
  factory :notification_type do
    sequence(:name) { |n| "notification_type_#{n}" }
    is_active { true }
    is_push { true }
    is_email { true }
    is_sms { false }
    template { "Hello {{name}}, this is a {{type}} notification" }

    trait :inactive do
      is_active { false }
    end

    trait :push_only do
      is_push { true }
      is_email { false }
      is_sms { false }
    end

    trait :email_only do
      is_push { false }
      is_email { true }
      is_sms { false }
    end

    trait :sms_only do
      is_push { false }
      is_email { false }
      is_sms { true }
    end

    trait :all_channels do
      is_push { true }
      is_email { true }
      is_sms { true }
    end

    # Common notification types
    trait :booking_created do
      name { 'booking_created' }
    end

    trait :booking_confirmed do
      name { 'booking_confirmed' }
    end

    trait :booking_cancelled do
      name { 'booking_cancelled' }
    end

    trait :booking_reminder do
      name { 'booking_reminder' }
    end

    trait :booking_completed do
      name { 'booking_completed' }
    end

    trait :system_notification do
      name { 'system_notification' }
    end
  end
end
