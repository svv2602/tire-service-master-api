# Создание украинских статей
puts "Создание украинских статей..."

# Находим админа
admin_user = User.find_by(email: 'admin@test.com')
if admin_user
  puts "Админ найден: #{admin_user.email}"
else
  puts "Админ не найден!"
  exit
end

# Создаем украинские статьи
ukrainian_articles = [
  {
    title: 'Як вибрати зимові шини: повний посібник',
    slug: 'yak-vybraty-zymovi-shyny',
    excerpt: 'Детальний посібник з вибору зимових шин для безпечної їзди в холодну пору року',
    content: 'Повний посібник з вибору зимових шин для українських автомобілістів. Розглядаємо типи шин, критерії вибору та рекомендації експертів.',
    category: 'selection',
    status: 'published',
    featured: true,
    reading_time: 8
  },
  {
    title: 'Правильний тиск у шинах: чому це важливо',
    slug: 'pravylnyj-tysk-u-shynah',
    excerpt: 'Вплив тиску в шинах на безпеку, витрату палива та довговічність шин',
    content: 'Детальна інформація про важливість правильного тиску в шинах. Наслідки неправильного тиску та рекомендації з обслуговування.',
    category: 'maintenance',
    status: 'published',
    featured: false,
    reading_time: 5
  },
  {
    title: 'Сезонне зберігання шин: правила та поради',
    slug: 'sezonne-zberigannya-shyn',
    excerpt: 'Як правильно зберігати шини в міжсезоння, щоб вони прослужили довше',
    content: 'Правила та поради щодо зберігання шин в міжсезоння. Умови зберігання, підготовка та корисні рекомендації.',
    category: 'seasonal',
    status: 'published',
    featured: false,
    reading_time: 6
  },
  {
    title: 'Ознаки зносу шин: коли пора міняти',
    slug: 'oznaky-znosu-shyn',
    excerpt: 'Як визначити, що шини потребують заміни, та на що звертати увагу',
    content: 'Основні ознаки зносу шин та рекомендації щодо заміни. Глибина протектора, візуальні ознаки та поради експертів.',
    category: 'safety',
    status: 'published',
    featured: true,
    reading_time: 7
  },
  {
    title: 'Балансування коліс: навіщо це потрібно',
    slug: 'balansuvannya-kolis',
    excerpt: 'Що таке балансування коліс, коли його робити та як це впливає на їзду',
    content: 'Детальна інформація про балансування коліс та його важливість. Ознаки дисбалансу, процес балансування та рекомендації.',
    category: 'maintenance',
    status: 'published',
    featured: false,
    reading_time: 5
  }
]

created_count = 0
ukrainian_articles.each do |article_data|
  begin
    # Проверяем, не существует ли уже статья с таким slug
    existing_article = Article.find_by(slug: article_data[:slug])
    if existing_article
      puts "⚠️  Статья с slug '#{article_data[:slug]}' уже существует, пропускаем"
      next
    end

    article = Article.create!(
      title: article_data[:title],
      slug: article_data[:slug],
      excerpt: article_data[:excerpt],
      content: article_data[:content],
      category: article_data[:category],
      status: article_data[:status],
      featured: article_data[:featured],
      reading_time: article_data[:reading_time],
      views_count: rand(100..300),
      author: admin_user,
      published_at: Time.current,
      allow_comments: true,
      meta_title: article_data[:title],
      meta_description: article_data[:excerpt],
      tags: ['шини', 'автомобіль', 'поради']
    )
    puts "✅ Створено українську статтю: #{article.title} (ID: #{article.id})"
    created_count += 1
  rescue => e
    puts "❌ Ошибка при создании статьи '#{article_data[:title]}': #{e.message}"
  end
end

puts "🎉 Створено #{created_count} нових українських статей!"
puts "📊 Всього статей в базі: #{Article.count}" 