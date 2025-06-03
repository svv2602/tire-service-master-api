FactoryBot.define do
  factory :manager do
    user
    partner { association :partner, :with_new_user }
    position { Faker::Job.position }
    access_level { 2 } # FULL_ACCESS по умолчанию
    
    trait :read_only do
      access_level { 1 } # READ_ONLY_ACCESS
    end
    
    trait :full_access do
      access_level { 2 } # FULL_ACCESS
    end
  end
end
