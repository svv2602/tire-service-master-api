FactoryBot.define do
  factory :car do
    association :client
    association :car_type
    sequence(:brand) { |n| "Brand#{n}" }
    sequence(:model) { |n| "Model#{n}" }
    year { rand(2010..Date.current.year) }
    sequence(:license_plate) { |n| "AA#{n.to_s.rjust(4, '0')}BB" }
    sequence(:vin) { |n| "1HGCM82633A00#{n.to_s.rjust(4, '0')}" }
    color { %w[White Black Silver Blue Red].sample }
    sequence(:notes) { |n| "Test car notes #{n}" }
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
