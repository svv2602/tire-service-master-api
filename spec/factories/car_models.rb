FactoryBot.define do
  factory :car_model do
    sequence(:name) { |n| "CarModel #{n}" }
    is_active { true }
    association :brand, factory: :car_brand
  end
end
