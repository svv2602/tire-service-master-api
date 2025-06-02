FactoryBot.define do
  factory :schedule_template do
    association :service_point
    association :weekday
    is_working_day { true }
    opening_time { Time.parse('09:00') }
    closing_time { Time.parse('18:00') }
    
    trait :non_working do
      is_working_day { false }
      opening_time { nil }
      closing_time { nil }
    end
  end
end 