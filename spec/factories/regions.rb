FactoryBot.define do
  factory :region do
    sequence(:name) { |n| "Region-#{Time.now.to_f}-#{n}" }
    is_active { true }
  end
end
