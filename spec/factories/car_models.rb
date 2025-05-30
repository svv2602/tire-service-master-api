FactoryBot.define do
  factory :car_model do
    sequence(:name) { |n| "#{Faker::Vehicle.model} #{n}" }
    is_active { true }
    association :brand, factory: :car_brand
  end
end
