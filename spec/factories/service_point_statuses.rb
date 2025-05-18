FactoryBot.define do
  factory :service_point_status do
    sequence(:name) { |n| ["active_#{n}", "inactive_#{n}", "pending_#{n}", "closed_#{n}"].sample }
    
    # Переопределим метод create для проверки существующих записей
    initialize_with do
      ServicePointStatus.find_by(name: name) || 
      ServicePointStatus.new(name: name)
    end
    
    trait :active do
      name { 'active' }
      
      initialize_with do
        ServicePointStatus.find_by(name: 'active') || 
        ServicePointStatus.new(name: 'active')
      end
    end
    
    trait :inactive do
      name { 'inactive' }
      
      initialize_with do
        ServicePointStatus.find_by(name: 'inactive') || 
        ServicePointStatus.new(name: 'inactive')
      end
    end
    
    trait :pending do
      name { 'pending' }
      
      initialize_with do
        ServicePointStatus.find_by(name: 'pending') || 
        ServicePointStatus.new(name: 'pending')
      end
    end
    
    trait :closed do
      name { 'closed' }
      
      initialize_with do
        ServicePointStatus.find_by(name: 'closed') || 
        ServicePointStatus.new(name: 'closed')
      end
    end
    
    factory :sp_active_status, traits: [:active]
    factory :sp_inactive_status, traits: [:inactive]
    factory :sp_pending_status, traits: [:pending]
    factory :sp_closed_status, traits: [:closed]
  end
end
