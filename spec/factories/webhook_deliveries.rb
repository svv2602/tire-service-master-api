FactoryBot.define do
  factory :webhook_delivery do
    webhook_endpoint
    event { 'booking.created' }
    payload { { event: 'booking.created', data: { id: 1 } } }
    status { 'pending' }
    attempt { 0 }

    trait :success do
      status { 'success' }
      response_code { 200 }
      attempt { 1 }
      delivered_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      response_code { 500 }
      attempt { 3 }
      error_message { 'HTTP 500: Internal Server Error' }
    end
  end
end
