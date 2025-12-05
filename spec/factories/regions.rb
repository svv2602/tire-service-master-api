FactoryBot.define do
  factory :region do
    sequence(:name) { |n| "Region #{n}" }
    sequence(:name_ru) { |n| "Регион #{n}" }
    sequence(:name_uk) { |n| "Регіон #{n}" }
    is_active { true }
  end
end
