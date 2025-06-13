FactoryBot.define do
  factory :car do
    association :client
    association :car_type
    brand { Faker::Vehicle.make }
    model { Faker::Vehicle.model }
    year { rand(2010..Date.current.year) }
    sequence(:license_plate) { |n| "AA#{n}BB#{rand(100..999)}" }
    vin { Faker::Vehicle.vin }
    color { Faker::Vehicle.color }
    notes { Faker::Lorem.paragraph }
    is_active { true }
    
    trait :inactive do
      is_active { false }
    end
    
    trait :toyota do
      brand { 'Toyota' }
      model { ['Camry', 'Corolla', 'RAV4', 'Land Cruiser'].sample }
    end
    
    trait :bmw do
      brand { 'BMW' }
      model { ['3 Series', '5 Series', 'X3', 'X5'].sample }
    end
    
    trait :mercedes do
      brand { 'Mercedes-Benz' }
      model { ['C-Class', 'E-Class', 'GLC', 'S-Class'].sample }
    end
  end
end
