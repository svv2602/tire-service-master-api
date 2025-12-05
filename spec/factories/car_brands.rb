FactoryBot.define do
  factory :car_brand do
    sequence(:name) { |n| "CarBrand #{n}" }
    logo { nil }
    is_active { true }
  end
end
