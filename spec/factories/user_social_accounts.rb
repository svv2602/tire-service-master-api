FactoryBot.define do
  factory :user_social_account do
    user
    sequence(:provider) { |n| ['google', 'facebook', 'apple'][n % 3] }
    sequence(:provider_user_id) { |n| "social_user_#{n}" }
    
    trait :google do
      provider { 'google' }
    end
    
    trait :facebook do
      provider { 'facebook' }
    end
    
    trait :apple do
      provider { 'apple' }
    end
  end
end
