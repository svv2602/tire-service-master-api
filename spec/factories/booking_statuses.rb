FactoryBot.define do
  factory :booking_status do
    sequence(:name) { |n| "status_#{n}" }
    is_active { true }
    sequence(:sort_order) { |n| n }
    
    # Переопределим метод create для проверки существующих записей
    initialize_with do
      BookingStatus.find_by(name: name) || 
      BookingStatus.new(name: name, is_active: is_active, sort_order: sort_order)
    end
    
    trait :pending do
      name { 'pending' }
      
      initialize_with do
        BookingStatus.find_by(name: 'pending') || 
        BookingStatus.new(name: 'pending', is_active: true, sort_order: 1)
      end
    end
    
    trait :confirmed do
      name { 'confirmed' }
      
      initialize_with do
        BookingStatus.find_by(name: 'confirmed') || 
        BookingStatus.new(name: 'confirmed', is_active: true, sort_order: 2)
      end
    end
    
    trait :in_progress do
      name { 'in_progress' }
      
      initialize_with do
        BookingStatus.find_by(name: 'in_progress') || 
        BookingStatus.new(name: 'in_progress', is_active: true, sort_order: 3)
      end
    end
    
    trait :completed do
      name { 'completed' }
      
      initialize_with do
        BookingStatus.find_by(name: 'completed') || 
        BookingStatus.new(name: 'completed', is_active: true, sort_order: 4)
      end
    end
    
    trait :canceled_by_client do
      name { 'canceled_by_client' }
      
      initialize_with do
        BookingStatus.find_by(name: 'canceled_by_client') || 
        BookingStatus.new(name: 'canceled_by_client', is_active: true, sort_order: 5)
      end
    end
    
    trait :canceled_by_partner do
      name { 'canceled_by_partner' }
      
      initialize_with do
        BookingStatus.find_by(name: 'canceled_by_partner') || 
        BookingStatus.new(name: 'canceled_by_partner', is_active: true, sort_order: 6)
      end
    end
    
    trait :no_show do
      name { 'no_show' }
      
      initialize_with do
        BookingStatus.find_by(name: 'no_show') || 
        BookingStatus.new(name: 'no_show', is_active: true, sort_order: 7)
      end
    end
    
    factory :pending_status, traits: [:pending]
    factory :confirmed_status, traits: [:confirmed]
    factory :in_progress_status, traits: [:in_progress]
    factory :completed_status, traits: [:completed]
    factory :canceled_by_client_status, traits: [:canceled_by_client]
    factory :canceled_by_partner_status, traits: [:canceled_by_partner]
    factory :no_show_status, traits: [:no_show]
  end
end
