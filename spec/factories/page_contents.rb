FactoryBot.define do
  factory :page_content do
    section { "MyString" }
    content_type { "MyString" }
    title { "MyText" }
    content { "MyText" }
    image_url { "MyText" }
    settings { "MyText" }
    position { 1 }
    active { false }
  end
end
