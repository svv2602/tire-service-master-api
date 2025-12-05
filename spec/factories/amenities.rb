FactoryBot.define do
  factory :amenity do
    sequence(:name) { |n| "Amenity #{n}" }
    icon { ["wifi", "parking", "toilet", "cafe", "waiting_room"].sample }
  end
end
