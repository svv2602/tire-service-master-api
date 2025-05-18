FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { 'password123' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    is_active { true }
    email_verified { true }
    phone { Faker::PhoneNumber.cell_phone_in_e164 }
    
    # Использует или создает роль 'client' по умолчанию
    after(:build) do |user|
      if user.role_id.nil?
        # Найти или создать запись роли клиента
        client_role = UserRole.find_by(name: 'client')
        
        unless client_role
          client_role = UserRole.create!(
            name: 'client',
            description: 'End users booking tire services',
            is_active: true
          )
        end
        
        user.role_id = client_role.id
      end
    end
    
    factory :admin do
      after(:create) do |user|
        create(:administrator, user: user)
      end
    end
    
    factory :client_user do
      after(:create) do |user|
        create(:client, user: user)
      end
    end
    
    factory :manager_user do
      after(:create) do |user|
        create(:manager, user: user)
      end
    end

    factory :partner_user do
      after(:create) do |user|
        create(:partner, user: user)
      end
    end
    
    trait :with_admin_role do
      association :role, factory: :user_role, name: 'admin'
    end
    
    trait :with_client_role do
      association :role, factory: :user_role, name: 'client'
    end
    
    trait :with_partner_role do
      association :role, factory: :user_role, name: 'partner'
    end
    
    trait :with_manager_role do
      association :role, factory: :user_role, name: 'manager'
    end
    
    trait :inactive do
      is_active { false }
    end
    
    trait :unverified do
      email_verified { false }
    end
  end
end
