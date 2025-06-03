FactoryBot.define do
  factory :partner do
    # По умолчанию не создаем пользователя - он должен быть передан явно
    user { nil }
    
    company_name { Faker::Company.name }
    company_description { Faker::Lorem.paragraph }
    contact_person { Faker::Name.name }
    legal_address { Faker::Address.full_address }
    website { Faker::Internet.url }
    tax_number { nil } # Теперь по умолчанию пустой
    is_active { true }
    
    # Трейт для создания с новым пользователем
    trait :with_new_user do
      user do
        partner_role = UserRole.find_by(name: 'partner') || 
                      FactoryBot.create(:user_role, name: 'partner', description: 'Partner role for business owners')
        
        FactoryBot.create(:user, role_id: partner_role.id)
      end
    end
    
    # Трейт для партнера с налоговым номером
    trait :with_tax_number do
      tax_number { "#{Faker::Number.number(digits: 10)}" }
    end
    
    # Трейт для полных данных
    trait :complete do
      with_tax_number
      with_new_user
      is_active { true }
      region { association :region }
      city { association :city }
    end
  end
end
