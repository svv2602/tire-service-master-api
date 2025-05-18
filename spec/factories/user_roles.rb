FactoryBot.define do
  factory :user_role do
    sequence(:name) { |n| ["admin#{n}", "client#{n}", "partner#{n}", "manager#{n}", "employee#{n}"][n % 5] }
    description { Faker::Lorem.sentence }
    is_active { true }
    
    # Переопределим метод create для проверки существующих записей
    initialize_with do
      UserRole.find_by(name: name) || UserRole.new(name: name, description: description, is_active: is_active)
    end
    
    trait :admin do
      name { 'administrator' }
      description { 'Administrator role with full access' }
      
      # Инициализация с поиском существующей записи
      initialize_with do
        UserRole.find_by(name: 'administrator') || 
        UserRole.new(name: 'administrator', description: 'Administrator role with full access', is_active: true)
      end
    end
    
    trait :client do
      name { 'client' }
      description { 'Client role for users who book services' }
      
      # Инициализация с поиском существующей записи
      initialize_with do
        UserRole.find_by(name: 'client') || 
        UserRole.new(name: 'client', description: 'Client role for users who book services', is_active: true)
      end
    end
    
    trait :partner do
      name { 'partner' }
      description { 'Partner role for business owners' }
      
      # Инициализация с поиском существующей записи
      initialize_with do
        UserRole.find_by(name: 'partner') || 
        UserRole.new(name: 'partner', description: 'Partner role for business owners', is_active: true)
      end
    end
    
    trait :manager do
      name { 'manager' }
      description { 'Manager role for service point managers' }
      
      # Инициализация с поиском существующей записи
      initialize_with do
        UserRole.find_by(name: 'manager') || 
        UserRole.new(name: 'manager', description: 'Manager role for service point managers', is_active: true)
      end
    end
  end
end
