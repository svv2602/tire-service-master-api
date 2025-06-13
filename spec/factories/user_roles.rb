FactoryBot.define do
  factory :user_role do
    sequence(:name) { |n| "role_#{n}" }
    sequence(:description) { |n| "Role description #{n}" }
    is_active { true }
    
    trait :admin do
      name { 'admin' }
      description { 'Administrator role with full access' }
    end
    
    trait :client do
      name { 'client' }
      description { 'Client role for users who book services' }
    end
    
    trait :partner do
      name { 'partner' }
      description { 'Partner role for business owners' }
    end
    
    trait :manager do
      name { 'manager' }
      description { 'Manager role for service point managers' }
    end
    
    trait :inactive do
      is_active { false }
    end
    
    # Фабрики для конкретных ролей
    factory :admin_role, traits: [:admin]
    factory :client_role, traits: [:client]
    factory :partner_role, traits: [:partner]
    factory :manager_role, traits: [:manager]
  end
end
