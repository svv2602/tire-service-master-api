# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    sequence(:payment_id) { |n| "booking_#{n}_#{Time.current.to_i}" }
    provider { 'liqpay' }
    payment_type { 'booking' }
    sequence(:entity_id) { |n| n }
    user
    amount { 1000.00 }
    currency { 'UAH' }
    status { 'pending' }
    description { 'Test payment' }

    trait :success do
      status { 'success' }
      paid_at { Time.current }
      sequence(:provider_payment_id) { |n| "txn_#{n}" }
    end

    trait :failed do
      status { 'failed' }
    end

    trait :refunded do
      status { 'refunded' }
      paid_at { 1.hour.ago }
      refunded_at { Time.current }
      refund_amount { 1000.00 }
    end

    trait :for_booking do
      payment_type { 'booking' }
    end

    trait :for_order do
      payment_type { 'order' }
    end
  end
end
