FactoryBot.define do
  factory :amenity do
    name { Faker::House.furniture }
    icon { ["wifi", "parking", "toilet", "cafe", "waiting_room"].sample }
  end
end
