FactoryBot.define do
  factory :booking do
    client
    service_point
    # Делаем car необязательным и nil по умолчанию
    car { nil }
    association :car_type, factory: :car_type
    association :slot, factory: :schedule_slot
    
    before(:build) do |booking|
      # Ensure all statuses exist
      BookingTestHelper.ensure_all_booking_statuses_exist if defined?(BookingTestHelper)
      
      # Set default statuses using find_or_create_by to ensure they exist
      booking.status_id = BookingStatus.find_or_create_by(
        name: 'pending',
        description: 'Pending status',
        color: '#FFC107',
        is_active: true,
        sort_order: 1
      ).id
      
      booking.payment_status_id = PaymentStatus.find_or_create_by(
        name: 'pending',
        description: 'Payment pending',
        color: '#FFC107',
        is_active: true,
        sort_order: 1
      ).id
    end
    
    booking_date { Date.current + 1.day }
    start_time { Time.parse('10:00') }
    end_time { Time.parse('11:00') }
    total_price { rand(1000..10000) }
    
    trait :with_services do
      after(:create) do |booking|
        create_list(:booking_service, 2, booking: booking)
      end
    end
    
    trait :past do
      booking_date { Date.current - 1.day }
    end
    
    trait :pending do
      before(:build) do |booking|
        booking.status_id = BookingStatus.find_or_create_by(
          name: 'pending',
          description: 'Pending status',
          color: '#FFC107',
          is_active: true,
          sort_order: 1
        ).id
      end
    end
    
    trait :confirmed do
      before(:build) do |booking|
        booking.status_id = BookingStatus.find_or_create_by(
          name: 'confirmed',
          description: 'Confirmed status',
          color: '#4CAF50',
          is_active: true,
          sort_order: 2
        ).id
      end
    end
    
    trait :in_progress do
      before(:build) do |booking|
        booking.status_id = BookingStatus.find_or_create_by(
          name: 'in_progress',
          description: 'In progress status',
          color: '#2196F3',
          is_active: true,
          sort_order: 3
        ).id
      end
    end
    
    trait :completed do
      before(:build) do |booking|
        booking.status_id = BookingStatus.find_or_create_by(
          name: 'completed',
          description: 'Completed status',
          color: '#8BC34A',
          is_active: true,
          sort_order: 4
        ).id
      end
    end
    
    trait :canceled_by_client do
      before(:build) do |booking|
        booking.status_id = BookingStatus.find_or_create_by(
          name: 'canceled_by_client',
          description: 'Canceled by client status',
          color: '#F44336',
          is_active: true,
          sort_order: 5
        ).id
        booking.cancellation_reason = create(:cancellation_reason)
      end
    end
    
    trait :canceled_by_partner do
      before(:build) do |booking|
        booking.status_id = BookingStatus.find_or_create_by(
          name: 'canceled_by_partner',
          description: 'Canceled by partner status',
          color: '#FF5722',
          is_active: true,
          sort_order: 6
        ).id
        booking.cancellation_reason = create(:cancellation_reason)
      end
    end
    
    trait :no_show do
      before(:build) do |booking|
        booking.status_id = BookingStatus.find_or_create_by(
          name: 'no_show',
          description: 'No show status',
          color: '#9C27B0',
          is_active: true,
          sort_order: 7
        ).id
      end
    end
    
    trait :today do
      booking_date { Date.current }
    end
  end
end
