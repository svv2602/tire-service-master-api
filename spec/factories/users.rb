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
        client_role = UserRole.find_by(name: 'client') || 
                     FactoryBot.create(:user_role, name: 'client', description: 'Client role for users who book services')
        
        user.role_id = client_role.id
      end
    end
    
    factory :admin do
      after(:build) do |user|
        admin_role = UserRole.find_by(name: 'admin') || 
                    FactoryBot.create(:user_role, name: 'admin', description: 'Administrator role with full access')
        user.role_id = admin_role.id
      end
      
      after(:create) do |user|
        create(:administrator, user: user)
      end
    end
    
    factory :client_user do
      after(:build) do |user|
        client_role = UserRole.find_by(name: 'client') || 
                     FactoryBot.create(:user_role, name: 'client', description: 'Client role for users who book services')
        user.role_id = client_role.id
      end
      
      after(:create) do |user|
        create(:client, user: user)
      end
    end
    
    factory :manager_user do
      after(:build) do |user|
        manager_role = UserRole.find_by(name: 'manager') || 
                      FactoryBot.create(:user_role, name: 'manager', description: 'Manager role for service point managers')
        user.role_id = manager_role.id
      end
      
      after(:create) do |user|
        create(:manager, user: user)
      end
    end

    factory :partner_user do
      after(:build) do |user|
        partner_role = UserRole.find_by(name: 'partner') || 
                      FactoryBot.create(:user_role, name: 'partner', description: 'Partner role for business owners')
        user.role_id = partner_role.id
      end
      
      after(:create) do |user|
        create(:partner, user: user)
      end
    end
    
    trait :with_admin_role do
      after(:build) do |user|
        admin_role = UserRole.find_by(name: 'admin') || 
                    FactoryBot.create(:user_role, name: 'admin', description: 'Administrator role with full access')
        user.role_id = admin_role.id
      end
    end
    
    trait :with_client_role do
      after(:build) do |user|
        client_role = UserRole.find_by(name: 'client') || 
                     FactoryBot.create(:user_role, name: 'client', description: 'Client role for users who book services')
        user.role_id = client_role.id
      end
    end
    
    trait :with_partner_role do
      after(:build) do |user|
        partner_role = UserRole.find_by(name: 'partner') || 
                      FactoryBot.create(:user_role, name: 'partner', description: 'Partner role for business owners')
        user.role_id = partner_role.id
      end
    end
    
    trait :with_manager_role do
      after(:build) do |user|
        manager_role = UserRole.find_by(name: 'manager') || 
                      FactoryBot.create(:user_role, name: 'manager', description: 'Manager role for service point managers')
        user.role_id = manager_role.id
      end
    end
    
    trait :inactive do
      is_active { false }
    end
    
    trait :unverified do
      email_verified { false }
    end

    trait :admin do
      after(:build) do |user|
        admin_role = UserRole.find_by(name: 'admin') || 
                    FactoryBot.create(:user_role, name: 'admin', description: 'Administrator role with full access')
        user.role_id = admin_role.id
      end
    end

    trait :manager do
      after(:build) do |user|
        manager_role = UserRole.find_by(name: 'manager') || 
                      FactoryBot.create(:user_role, name: 'manager', description: 'Manager role for service point managers')
        user.role_id = manager_role.id
      end
    end

    trait :client do
      after(:build) do |user|
        client_role = UserRole.find_by(name: 'client') || 
                     FactoryBot.create(:user_role, name: 'client', description: 'Client role for users who book services')
        user.role_id = client_role.id
      end
    end
  end
end
