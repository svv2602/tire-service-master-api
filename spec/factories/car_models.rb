FactoryBot.define do
  factory :car_model do
    sequence(:name) { |n| "#{Faker::Vehicle.model} #{n}" }
    association :brand, factory: :car_brand
  end
end
