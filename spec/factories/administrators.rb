FactoryBot.define do
  factory :administrator do
    user
    position { 'System Administrator' }
    access_level { 1 }
  end
end
