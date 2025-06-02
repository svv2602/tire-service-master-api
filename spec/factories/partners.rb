FactoryBot.define do
  factory :partner do
    # Не создаем пользователя автоматически, требуем явной передачи
    # Это решает проблему с дублированием пользователей в тестах
    
    company_name { Faker::Company.name }
    company_description { Faker::Lorem.paragraph }
    contact_person { Faker::Name.name }
    legal_address { Faker::Address.full_address }
    website { Faker::Internet.url }
    tax_number { nil } # Теперь по умолчанию пустой
    is_active { true }
    
    # Трейт для партнера с налоговым номером
    trait :with_tax_number do
      tax_number { "#{Faker::Number.number(digits: 10)}" }
    end
    
    # Трейт для полных данных
    trait :complete do
      with_tax_number
      is_active { true }
      region { association :region }
      city { association :city }
    end
    
    # Трейт для создания с пользователем партнера
    trait :with_partner_user do
      association :user, factory: [:user, :with_partner_role]
    end
  end
end
