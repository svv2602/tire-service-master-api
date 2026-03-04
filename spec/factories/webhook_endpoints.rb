FactoryBot.define do
  factory :webhook_endpoint do
    partner
    sequence(:url) { |n| "https://example.com/webhooks/#{n}" }
    secret { SecureRandom.hex(32) }
    events { ['booking.created', 'booking.confirmed'] }
    is_active { true }
    description { 'Test webhook endpoint' }

    trait :inactive do
      is_active { false }
    end

    trait :all_events do
      events { WebhookEndpoint::SUPPORTED_EVENTS }
    end

    trait :booking_events do
      events { %w[booking.created booking.confirmed booking.completed] }
    end

    trait :order_events do
      events { %w[order.status_changed] }
    end

    trait :review_events do
      events { %w[review.created] }
    end
  end
end
