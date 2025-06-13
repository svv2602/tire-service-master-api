FactoryBot.define do
  factory :client do
    association :user, factory: [:user, :client]
    preferred_notification_method { 'email' }
    marketing_consent { true }

    trait :with_car do
      after(:create) do |client|
        create(:client_car, client: client)
      end
    end
    
    trait :with_multiple_cars do
      after(:create) do |client|
        create_list(:client_car, 3, client: client)
      end
    end
    
    trait :without_marketing_consent do
      marketing_consent { false }
    end

    trait :with_cars do
      transient do
        cars_count { 2 }
      end

      after(:create) do |client, evaluator|
        # Create regular cars with unique brands/models
        evaluator.cars_count.times do |i|
          brand = create(:car_brand, name: "Brand #{i}")
          model = create(:car_model, brand: brand, name: "Model #{i}")
          create(:client_car, client: client, brand: brand, model: model, is_primary: false)
        end
        
        # Create a primary car with unique brand/model
        primary_brand = create(:car_brand, name: "Primary Brand")
        primary_model = create(:car_model, brand: primary_brand, name: "Primary Model")
        create(:client_car, client: client, brand: primary_brand, model: primary_model, is_primary: true)
      end
    end

    trait :with_favorite_points do
      transient do
        favorite_points_count { 2 }
      end

      after(:create) do |client, evaluator|
        create_list(:client_favorite_point, evaluator.favorite_points_count, client: client)
      end
    end
  end
end
