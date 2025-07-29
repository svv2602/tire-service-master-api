FactoryBot.define do
  factory :partner_application do
    company_name { Faker::Company.name }
    business_description { Faker::Lorem.paragraph(sentence_count: 3) }
    contact_person { Faker::Name.name }
    email { Faker::Internet.unique.email }
    phone { "+380#{Faker::Number.number(digits: 9)}" }
    city { Faker::Address.city }
    address { Faker::Address.street_address }
    website { Faker::Internet.url }
    additional_info { Faker::Lorem.paragraph }
    expected_service_points { rand(1..5) }
    status { 'new' }

    # Трейты для разных статусов
    trait :pending do
      status { 'new' }
    end

    trait :in_progress do
      status { 'in_progress' }
      processed_at { 1.day.ago }
      association :processed_by, factory: [:user, :admin]
    end

    trait :approved do
      status { 'approved' }
      processed_at { 2.days.ago }
      admin_notes { 'Отличные рекомендации, одобрено' }
      association :processed_by, factory: [:user, :admin]
    end

    trait :rejected do
      status { 'rejected' }
      processed_at { 3.days.ago }
      admin_notes { 'Недостаточно документов для подтверждения' }
      association :processed_by, factory: [:user, :admin]
    end

    trait :connected do
      status { 'connected' }
      processed_at { 5.days.ago }
      admin_notes { 'Партнер успешно подключен к системе' }
      association :processed_by, factory: [:user, :admin]
    end

    # Трейт с привязкой к региону и городу
    trait :with_location do
      association :region
      association :city_record, factory: :city
    end

    # Трейт для полных данных
    trait :complete do
      with_location
      website { Faker::Internet.url }
      additional_info { Faker::Lorem.paragraph }
    end

    # Трейт для минимальных данных
    trait :minimal do
      website { nil }
      additional_info { nil }
      address { nil }
    end
  end
end 