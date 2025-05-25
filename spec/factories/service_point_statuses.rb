FactoryBot.define do
  factory :service_point_status do
    sequence(:name) { |n| ["active_#{n}", "inactive_#{n}", "pending_#{n}", "closed_#{n}"].sample }
    description { "Статус сервисной точки: #{name}" }
    color { "#FFFFFF" }
    is_active { true }
    sort_order { 1 }
    
    trait :active do
      name { 'active' }
      description { 'Активная сервисная точка' }
      color { '#28a745' }
      sort_order { 1 }
    end
    
    trait :inactive do
      name { 'inactive' }
      description { 'Неактивная сервисная точка' }
      color { '#6c757d' }
      sort_order { 2 }
    end
    
    trait :pending do
      name { 'pending' }
      description { 'Ожидающая активации' }
      color { '#ffc107' }
      sort_order { 3 }
    end
    
    trait :closed do
      name { 'closed' }
      description { 'Закрытая сервисная точка' }
      color { '#dc3545' }
      sort_order { 4 }
    end
    
    trait :temporarily_closed do
      name { 'temporarily_closed' }
      description { 'Временно закрытая' }
      color { '#fd7e14' }
      sort_order { 5 }
    end
    
    trait :maintenance do
      name { 'maintenance' }
      description { 'На техническом обслуживании' }
      color { '#17a2b8' }
      sort_order { 6 }
    end
    
    factory :sp_active_status, traits: [:active]
    factory :sp_inactive_status, traits: [:inactive]
    factory :sp_pending_status, traits: [:pending]
    factory :sp_closed_status, traits: [:closed]
    factory :sp_temporarily_closed_status, traits: [:temporarily_closed]
    factory :sp_maintenance_status, traits: [:maintenance]
  end
end
