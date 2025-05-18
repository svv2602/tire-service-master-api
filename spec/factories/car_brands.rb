FactoryBot.define do
  factory :car_brand do
    name { Faker::Vehicle.make }
    logo { "https://example.com/logos/#{name.downcase}.png" }
  end
end
