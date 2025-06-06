FactoryBot.define do
  factory :article do
    title { Faker::Lorem.sentence(word_count: 4) }
    content { Faker::Lorem.paragraphs(number: 5).join("\n\n") }
    excerpt { Faker::Lorem.paragraph(sentence_count: 2) }
    category { %w[seasonal tips maintenance selection safety].sample }
    status { 'published' }
    featured { false }
    published_at { Time.current }
    views_count { 0 }
    reading_time { 3 }
    
    # Связь с автором (админ)
    association :author, factory: [:user, :admin]

    # Дополнительные поля для SEO
    meta_title { title }
    meta_description { excerpt }
    
    # Изображения (опционально)
    featured_image_url { Faker::Internet.url }
    
    trait :published do
      status { 'published' }
      published_at { 1.day.ago }
    end

    trait :draft do
      status { 'draft' }
      published_at { nil }
    end

    trait :featured do
      status { 'published' }
      featured { true }
      published_at { 1.week.ago }
    end

    trait :with_long_content do
      content { Faker::Lorem.paragraphs(number: 20).join("\n\n") }
      reading_time { 8 }
    end

    trait :seasonal do
      category { 'seasonal' }
      title { "Когда менять шины на зимние в #{Date.current.year} году" }
      content do
        "
        С приходом осени каждый автовладелец задается вопросом - когда пора менять летнюю резину на зимнюю?
        
        Эксперты рекомендуют следующие критерии:
        
        ## Температура воздуха
        Основной критерий - стабильная температура воздуха ниже +7°C. При такой температуре летняя резина начинает твердеть и терять сцепление с дорогой.
        
        ## Календарные сроки
        В средней полосе России оптимальное время для смены резины:
        - На зимнюю: середина-конец октября
        - На летнюю: апрель-начало мая
        
        ## Прогноз погоды
        Следите за долгосрочным прогнозом погоды. Если синоптики обещают похолодание на неделю и более - время менять резину.
        
        ## Важные моменты
        - Не ждите первого снега или гололеда
        - Записывайтесь в шиномонтаж заранее
        - Проверьте состояние зимних шин перед установкой
        "
      end
    end

    trait :tips do
      category { 'tips' }
      title { "#{Faker::Number.between(from: 5, to: 10)} советов по выбору шиномонтажа" }
    end

    trait :maintenance do
      category { 'maintenance' }
      title { "Как правильно хранить шины в межсезонье" }
    end

    # После создания вычисляем время чтения
    after(:build) do |article|
      if article.content.present?
        words_count = article.content.split.length
        article.reading_time = [(words_count / 200.0).ceil, 1].max # ~200 слов в минуту
      end
    end
  end
end