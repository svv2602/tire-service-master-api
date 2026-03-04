FactoryBot.define do
  factory :loyalty_account do
    association :user
    points { 0 }
    level { 'bronze' }

    trait :bronze do
      points { 50 }
      level { 'bronze' }
    end

    trait :silver do
      points { 250 }
      level { 'silver' }
    end

    trait :gold do
      points { 600 }
      level { 'gold' }
    end
  end
end
