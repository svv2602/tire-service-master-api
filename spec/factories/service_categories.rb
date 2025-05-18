FactoryBot.define do
  factory :service_category do
    sequence(:name) { |n| "Category #{n} - #{['Tire Change', 'Wheel Alignment', 'Brake Service', 'Oil Change'].sample}" }
  end
end
