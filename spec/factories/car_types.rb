FactoryBot.define do
  factory :car_type do
    sequence(:name) { |n| "CarType-#{Time.now.to_f}-#{n}" }
    description { Faker::Lorem.sentence }
    is_active { true }
    
    # Helper traits for common car types
    trait :suv do
      # Instead of setting name directly, find or create the SUV record and return it
      after(:build) do |car_type|
        existing = CarType.find_or_create_by(name: 'SUV') do |ct|
          ct.description = 'Sport utility vehicle'
          ct.is_active = true
        end
        
        # Copy all attributes from existing record
        car_type.id = existing.id
        car_type.name = existing.name
        car_type.description = existing.description
        car_type.is_active = existing.is_active
        car_type.created_at = existing.created_at
        car_type.updated_at = existing.updated_at
      end
    end
    
    trait :sedan do
      # Instead of setting name directly, find or create the Sedan record and return it
      after(:build) do |car_type|
        existing = CarType.find_or_create_by(name: 'Sedan') do |ct|
          ct.description = 'Standard sedan vehicle'
          ct.is_active = true
        end
        
        # Copy all attributes from existing record
        car_type.id = existing.id
        car_type.name = existing.name
        car_type.description = existing.description
        car_type.is_active = existing.is_active
        car_type.created_at = existing.created_at
        car_type.updated_at = existing.updated_at
      end
    end
  end
end
