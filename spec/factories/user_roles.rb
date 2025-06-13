FactoryBot.define do
  factory :user_role do
    sequence(:name) { |n| "role_#{n}" }
    description { "Тестовая роль" }
    is_active { true }
    
    trait :admin do
      name { 'admin' }
      description { 'Администратор системы' }
    end
    
    trait :manager do
      name { 'manager' }
      description { 'Менеджер' }
    end
    
    trait :operator do
      name { 'operator' }
      description { 'Оператор' }
    end
    
    trait :partner do
      name { 'partner' }
      description { 'Партнер' }
    end
    
    trait :client do
      name { 'client' }
      description { 'Клиент' }
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
