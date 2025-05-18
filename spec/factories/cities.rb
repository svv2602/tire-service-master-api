FactoryBot.define do
  factory :city do
    sequence(:name) { |n| "#{Faker::Address.city} #{n}-#{Time.now.to_f}" }
    region
    is_active { true }
  end
end
