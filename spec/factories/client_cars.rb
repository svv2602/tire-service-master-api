FactoryBot.define do
  factory :client_car do
    association :client, factory: :client
    association :brand, factory: :car_brand
    association :model, factory: :car_model
    association :car_type, factory: :car_type
    year { rand(2000..2023) }
    # Убираем поля, которых нет в схеме
    # sequence(:registration_number) { |n| "AA#{n}BB" }
    # sequence(:vin) { |n| "VIN#{n}#{SecureRandom.hex(4).upcase}" }
    is_primary { false }
    
    trait :primary do
      is_primary { true }
    end
  end
end
