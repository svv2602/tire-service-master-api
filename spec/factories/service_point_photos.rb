FactoryBot.define do
  factory :service_point_photo do
    association :service_point
    sort_order { 1 }

    after(:build) do |photo|
      unless photo.file.attached?
        file_path = Rails.root.join('spec', 'fixtures', 'files', 'test_logo.png')
        photo.file.attach(
          io: File.open(file_path),
          filename: 'test_logo.png',
          content_type: 'image/png'
        )
      end
    end
  end
end 