FactoryBot.define do
  factory :service_point_photo do
    service_point
    photo_url { "https://example.com/photos/#{SecureRandom.hex(8)}.jpg" }
    sort_order { rand(1..10) }
  end
end 