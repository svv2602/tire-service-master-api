# db/seeds/05_reviews.rb
# Создание отзывов для сервисных точек

puts '=== Создание отзывов для сервисных точек ==='

# Получаем данные
service_points = ServicePoint.all
clients = Client.all

if service_points.empty?
  puts "❌ Нет сервисных точек для добавления отзывов"
  return
end

if clients.empty?
  puts "❌ Нет клиентов для создания отзывов"
  return
end

# Шаблоны отзывов
positive_reviews = [
  {
    rating: 5,
    comment: "Відмінний сервіс! Швидко і якісно поміняли шини. Персонал дуже ввічливий та професійний. Обов'язково повернуся ще раз!",
    pros: "Швидкість обслуговування, професіоналізм, чистота",
    cons: nil
  },
  {
    rating: 5,
    comment: "Дуже задоволений обслуговуванням! Зробили балансування коліс швидко та якісно. Ціни адекватні, персонал знає свою справу.",
    pros: "Якість роботи, швидкість, ціна",
    cons: nil
  },
  {
    rating: 4,
    comment: "Хороший шиномонтаж. Швидко виконали заміну шин, все акуратно. Єдиний мінус - довелося трохи почекати в черзі.",
    pros: "Якість роботи, акуратність",
    cons: "Невелика черга"
  },
  {
    rating: 5,
    comment: "Рекомендую! Професійні майстри, сучасне обладнання. Зробили діагностику ходової частини - виявили проблеми, які не помічали в інших СТО.",
    pros: "Професіоналізм, сучасне обладнання, детальна діагностика",
    cons: nil
  },
  {
    rating: 4,
    comment: "Гарний сервіс, швидко поміняли масло та фільтри. Персонал пояснив що і навіщо робить. Ціни нормальні.",
    pros: "Швидкість, пояснення роботи, адекватні ціни",
    cons: nil
  }
]

neutral_reviews = [
  {
    rating: 3,
    comment: "Обслуговування нормальне, але нічого особливого. Зробили що треба, але без особливого ентузіазму.",
    pros: "Виконали роботу",
    cons: "Не дуже дружелюбний персонал"
  },
  {
    rating: 3,
    comment: "Середній рівень сервісу. Роботу виконали, але ціни трохи завищені. Можна знайти дешевше в інших місцях.",
    pros: "Виконали роботу вчасно",
    cons: "Завищені ціни"
  }
]

negative_reviews = [
  {
    rating: 2,
    comment: "Не дуже задоволений. Довго чекав, а потім ще й знайшли подряпину на диску, якої раніше не було.",
    pros: nil,
    cons: "Довге очікування, пошкодження диска"
  }
]

# Всі шаблони разом
all_reviews = positive_reviews + neutral_reviews + negative_reviews

created_count = 0
updated_count = 0

service_points.each do |service_point|
  puts "  💬 Создание отзывов для: #{service_point.name}"
  
  # Создаем 3-6 отзывов для каждой точки
  reviews_count = rand(3..6)
  
  reviews_count.times do |index|
    # Выбираем случайного клиента
    client = clients.sample
    
    # Проверяем, не оставлял ли уже этот клиент отзыв для этой точки
    existing_review = Review.find_by(
      service_point: service_point,
      client: client
    )
    
    if existing_review
      # Обновляем существующий отзыв
      review_template = all_reviews.sample
      existing_review.update!(
        rating: review_template[:rating],
        comment: review_template[:comment],
        is_published: true
      )
      updated_count += 1
      puts "    ✏️  Обновлен отзыв от: #{client.id} (#{review_template[:rating]}⭐)"
    else
      # Создаем новый отзыв
      review_template = all_reviews.sample
      
      Review.create!(
        service_point: service_point,
        client: client,
        rating: review_template[:rating],
        comment: review_template[:comment],
        is_published: true,
        created_at: rand(30.days.ago..Time.current)
      )
      created_count += 1
      puts "    ✨ Создан отзыв от: #{client.id} (#{review_template[:rating]}⭐)"
    end
  end
end

puts ""
puts "📊 Результат:"
puts "  Создано новых отзывов: #{created_count}"
puts "  Обновлено существующих отзывов: #{updated_count}"
puts "  Всего отзывов в системе: #{Review.count}"

# Статистика по рейтингам
puts ""
puts "📈 Статистика отзывов по сервисным точкам:"
ServicePoint.includes(:reviews).each do |sp|
  reviews = sp.reviews
  if reviews.any?
    avg_rating = reviews.average(:rating).round(1)
    rating_counts = reviews.group(:rating).count
    puts "  #{sp.name}: #{reviews.count} отзывов, средний рейтинг: #{avg_rating}⭐"
    rating_counts.each { |rating, count| puts "    #{rating}⭐: #{count} отзывов" }
  else
    puts "  #{sp.name}: нет отзывов"
  end
end

puts ""
puts "✅ Отзывы для сервисных точек успешно созданы/обновлены!" 