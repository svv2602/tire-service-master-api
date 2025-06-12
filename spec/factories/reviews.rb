FactoryBot.define do
  factory :review do
    before(:build) do |review|
      # Создаем клиента и сервисную точку, если они не заданы
      review.client ||= create(:client)
      review.service_point ||= create(:service_point)
      
      # Создаем бронирование со статусом "completed", если оно не задано
      if review.booking.nil?
        review.booking = create(:booking, :completed,
          client: review.client,
          service_point: review.service_point,
          skip_status_validation: true,
          skip_availability_check: true
        )
      end
    end
    
    rating { rand(1..5) }
    comment { Faker::Lorem.paragraph }
    is_published { true }
    
    trait :unpublished do
      is_published { false }
    end
    
    trait :with_low_rating do
      rating { 1 }
    end
    
    trait :with_high_rating do
      rating { 5 }
    end
  end
end
