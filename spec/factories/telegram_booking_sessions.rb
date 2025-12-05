FactoryBot.define do
  factory :telegram_booking_session do
    sequence(:chat_id) { |n| "#{100000000 + n}" }
    current_step { "city_selection" }
    session_data { {}.to_json }
    expires_at { 1.hour.from_now }

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :city_selection do
      current_step { "city_selection" }
    end

    trait :service_selection do
      current_step { "service_selection" }
      session_data { { city_id: 1 }.to_json }
    end

    trait :service_point_selection do
      current_step { "service_point_selection" }
      session_data { { city_id: 1, service_category_id: 1 }.to_json }
    end

    trait :datetime_selection do
      current_step { "datetime_selection" }
      session_data { { city_id: 1, service_category_id: 1, service_point_id: 1 }.to_json }
    end

    trait :phone_input do
      current_step { "phone_input" }
      session_data { { city_id: 1, service_category_id: 1, service_point_id: 1, date: Date.tomorrow.to_s, time: "10:00", car_type_id: 1 }.to_json }
    end

    trait :license_plate_input do
      current_step { "license_plate_input" }
      session_data { { city_id: 1, service_category_id: 1, service_point_id: 1, date: Date.tomorrow.to_s, time: "10:00", car_type_id: 1, phone: "+380671234567" }.to_json }
    end

    trait :confirmation do
      current_step { "confirmation" }
      session_data { { city_id: 1, service_category_id: 1, service_point_id: 1, date: Date.tomorrow.to_s, time: "10:00", car_type_id: 1, phone: "+380671234567", license_plate: "AA1234BB" }.to_json }
    end

    # Helper methods (transient attributes with methods)
    after(:build) do |session|
      session.define_singleton_method(:get_data) do |key|
        data = JSON.parse(session.session_data || '{}')
        data[key.to_s]
      end

      session.define_singleton_method(:booking_data) do
        JSON.parse(session.session_data || '{}').symbolize_keys
      end

      session.define_singleton_method(:update_step) do |step, new_data = {}|
        data = JSON.parse(session.session_data || '{}')
        data.merge!(new_data.stringify_keys)
        session.update!(current_step: step, session_data: data.to_json)
      end
    end
  end
end
