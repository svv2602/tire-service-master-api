FactoryBot.define do
  factory :supplier_tire_product do
    supplier
    sequence(:external_id) { |n| "EXT-#{n}" }
    original_brand { 'Michelin' }
    brand_normalized { 'michelin' }
    original_model { 'Pilot Sport 4' }
    sequence(:name) { |n| "Michelin Pilot Sport 4 225/45 R17 #{n}" }
    width { 225 }
    height { 45 }
    diameter { '17' }
    load_index { '94' }
    speed_index { 'Y' }
    season { 'summer' }
    price_uah { 4500.00 }
    stock_status { 'in_stock' }
    in_stock { true }

    trait :out_of_stock do
      stock_status { 'out_of_stock' }
      in_stock { false }
    end

    trait :winter do
      season { 'winter' }
      original_model { 'X-Ice Snow' }
    end
  end
end
