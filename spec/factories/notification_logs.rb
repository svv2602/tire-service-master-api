FactoryBot.define do
  factory :notification_log do
    notification_type { "MyString" }
    recipient_type { "MyString" }
    recipient_id { 1 }
    recipient_email { "MyString" }
    template_type { "MyString" }
    template_id { 1 }
    status { "MyString" }
    sent_at { "2025-07-21 23:48:30" }
    delivered_at { "2025-07-21 23:48:30" }
    opened_at { "2025-07-21 23:48:30" }
    clicked_at { "2025-07-21 23:48:30" }
    error_message { "MyText" }
    metadata { "" }
  end
end
