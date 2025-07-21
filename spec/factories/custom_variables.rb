FactoryBot.define do
  factory :custom_variable do
    name { "MyString" }
    description { "MyText" }
    example_value { "MyString" }
    category { "MyString" }
    is_active { false }
    created_by { nil }
  end
end
