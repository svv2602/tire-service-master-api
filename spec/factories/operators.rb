FactoryBot.define do
  factory :operator do
    association :user, factory: :user, role: UserRole.find_by(name: 'operator')
    position { ['Старший оператор', 'Оператор колл-центра', 'Оператор техподдержки'].sample }
    access_level { rand(1..5) }
    is_active { true }
  end
end
