FactoryBot.define do
  factory :booking_conflict do
    booking { nil }
    conflict_type { "MyString" }
    conflict_reason { "MyText" }
    detected_at { "2025-07-12 09:21:04" }
    resolved_at { "2025-07-12 09:21:04" }
    resolution_type { "MyString" }
    resolution_notes { "MyText" }
    resolved_by { nil }
    status { "MyString" }
  end
end
