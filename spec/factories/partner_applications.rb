FactoryBot.define do
  factory :partner_application do
    sequence(:company_name) { |n| "Partner Company #{n}" }
    sequence(:business_description) { |n| "Business description #{n}. This is a detailed description of the business." }
    sequence(:contact_person) { |n| "Contact Person #{n}" }
    sequence(:email) { |n| "partner_application#{n}@example.com" }
    sequence(:phone) { |n| "+38067#{100_0000 + n}" }
    sequence(:city) { |n| "City #{n}" }
    sequence(:address) { |n| "Test Address #{n}" }
    sequence(:website) { |n| "https://company#{n}.example.com" }
    sequence(:additional_info) { |n| "Additional info #{n}" }
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
    end

    # Трейт для минимальных данных
    trait :minimal do
      website { nil }
      additional_info { nil }
      address { nil }
    end
  end
end 