FactoryBot.define do
  factory :car_brand do
    sequence(:name) { |n| "#{Faker::Vehicle.make} #{n}" }
    logo { Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'files', 'test_logo.png'), 'image/png') }
    is_active { true }
  end
end
