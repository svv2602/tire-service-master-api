FactoryBot.define do
  factory :loyalty_transaction do
    association :loyalty_account
    points { 10 }
    reason { 'booking_completed' }
    description { 'Points for completed booking' }

    trait :review do
      points { 5 }
      reason { 'review_submitted' }
      description { 'Points for submitted review' }
    end

    trait :referral do
      points { 50 }
      reason { 'referral' }
      description { 'Referral bonus' }
    end

    trait :tire_order do
      points { 15 }
      reason { 'tire_order' }
      description { 'Points for tire order' }
    end

    trait :debit do
      points { -10 }
      reason { 'points_redeemed' }
      description { 'Points redeemed' }
    end
  end
end
