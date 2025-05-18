FactoryBot.define do
  factory :partner do
    # Сначала создаем роль 'partner', если она не существует
    after(:build) do |partner|
      # Найти или создать запись роли
      role = UserRole.find_by(name: 'partner')
      
      unless role
        role = UserRole.create!(
          name: 'partner',
          description: 'Business owners providing tire services',
          is_active: true
        )
      end
      
      # Если у партнера еще нет пользователя, создаем его
      unless partner.user
        partner.user = create(:user, role_id: role.id)
      end
    end
    
    company_name { Faker::Company.name }
    company_description { Faker::Lorem.paragraph }
    contact_person { Faker::Name.name }
    legal_address { Faker::Address.full_address }
    website { Faker::Internet.url }
    tax_number { "#{Faker::Number.number(digits: 10)}" }
  end
end
