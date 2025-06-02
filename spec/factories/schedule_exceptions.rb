FactoryBot.define do
  factory :schedule_exception do
    association :service_point
    exception_date { Date.current + 1.day }
    is_closed { true }
    reason { "Выходной день" }
    opening_time { nil }
    closing_time { nil }
    
    trait :special_hours do
      is_closed { false }
      opening_time { Time.parse('10:00') }
      closing_time { Time.parse('16:00') }
      reason { "Сокращенный рабочий день" }
    end
  end
end 