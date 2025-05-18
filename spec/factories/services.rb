FactoryBot.define do
  factory :service do
    name { Faker::Commerce.product_name }
    description { Faker::Lorem.paragraph }
    default_duration { [30, 60, 90, 120].sample }
    sort_order { rand(1..10) }
    is_active { true }
    association :category, factory: :service_category
  end
end
