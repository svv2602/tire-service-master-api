FactoryBot.define do
  factory :weekday do
    sequence(:name) { |n| ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"][n % 7] }
    sequence(:sort_order) { |n| (n % 7) + 1 }
  end
end 