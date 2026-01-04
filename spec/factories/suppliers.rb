FactoryBot.define do
  factory :supplier do
    sequence(:firm_id) { |n| "SUPPLIER#{n}" }
    sequence(:name) { |n| "Test Supplier #{n}" }
    sequence(:api_key) { |n| SecureRandom.hex(32) }
    is_active { true }
    priority { 0 }
  end
end
