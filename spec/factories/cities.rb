FactoryBot.define do
  factory :city do
    sequence(:name) { |n| "City #{n}" }
    sequence(:name_ru) { |n| "Город #{n}" }
    sequence(:name_uk) { |n| "Місто #{n}" }
    region
    is_active { true }
  end
end
