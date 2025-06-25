# Многоязычные статьи для базы знаний
puts "=== Создание многоязычных статей ==="

# Находим или создаем админа для статей
admin_user = User.find_by(email: 'admin@test.com')
unless admin_user
  puts "❌ Админ не найден! Сначала запустите create_admin_user.rb"
  exit
end

puts "✅ Автор статей: #{admin_user.email}"

# Проверяем существующие статьи (не удаляем для идемпотентности)
existing_count = Article.count
puts "📊 Существующих статей: #{existing_count}"
if existing_count > 0
  puts "ℹ️  Статьи уже существуют. Пропускаем создание для избежания дублирования."
  puts "   Если нужно пересоздать статьи, используйте: Article.destroy_all перед запуском"
  exit
end

# =============================================================================
# АНГЛИЙСКИЕ СТАТЬИ (базовые для SEO)
# =============================================================================
puts "\n🇺🇸 Создание английских статей..."

english_articles = [
  {
    title: 'How to Choose Winter Tires: Complete Guide',
    slug: 'how-to-choose-winter-tires',
    excerpt: 'Complete guide on selecting the right winter tires for safe driving in cold weather',
    content: 'Comprehensive guide for choosing winter tires. Learn about tire types, size selection, and expert recommendations for safe winter driving.',
    category: 'selection',
    status: 'published',
    featured: true,
    reading_time: 8,
    language: 'en'
  },
  {
    title: 'Proper Tire Pressure: Why It Matters',
    slug: 'proper-tire-pressure-guide',
    excerpt: 'Impact of tire pressure on safety, fuel consumption and tire longevity',
    content: 'Detailed information about the importance of proper tire pressure. Effects of incorrect pressure and maintenance recommendations.',
    category: 'maintenance',
    status: 'published',
    featured: false,
    reading_time: 5,
    language: 'en'
  },
  {
    title: 'Seasonal Tire Storage: Rules and Tips',
    slug: 'seasonal-tire-storage-guide',
    excerpt: 'How to properly store tires during off-season to extend their lifespan',
    content: 'Rules and tips for off-season tire storage. Storage conditions, preparation and useful recommendations.',
    category: 'seasonal',
    status: 'published',
    featured: false,
    reading_time: 6,
    language: 'en'
  }
]

# =============================================================================
# УКРАИНСКИЕ СТАТЬИ (основной язык сайта)
# =============================================================================
puts "\n🇺🇦 Создание украинских статей..."

ukrainian_articles = [
  {
    title: 'Як вибрати зимові шини: повний посібник',
    slug: 'yak-vybraty-zymovi-shyny',
    excerpt: 'Детальний посібник з вибору зимових шин для безпечної їзди в холодну пору року',
    content: 'Повний посібник з вибору зимових шин для українських автомобілістів. Розглядаємо типи шин, критерії вибору та рекомендації експертів.',
    category: 'selection',
    status: 'published',
    featured: true,
    reading_time: 8,
    language: 'uk'
  },
  {
    title: 'Правильний тиск у шинах: чому це важливо',
    slug: 'pravylnyj-tysk-u-shynah',
    excerpt: 'Вплив тиску в шинах на безпеку, витрату палива та довговічність шин',
    content: 'Детальна інформація про важливість правильного тиску в шинах. Наслідки неправильного тиску та рекомендації з обслуговування.',
    category: 'maintenance',
    status: 'published',
    featured: false,
    reading_time: 5,
    language: 'uk'
  },
  {
    title: 'Сезонне зберігання шин: правила та поради',
    slug: 'sezonne-zberigannya-shyn',
    excerpt: 'Як правильно зберігати шини в міжсезоння, щоб вони прослужили довше',
    content: 'Правила та поради щодо зберігання шин в міжсезоння. Умови зберігання, підготовка та корисні рекомендації.',
    category: 'seasonal',
    status: 'published',
    featured: false,
    reading_time: 6,
    language: 'uk'
  },
  {
    title: 'Ознаки зносу шин: коли пора міняти',
    slug: 'oznaky-znosu-shyn',
    excerpt: 'Як визначити, що шини потребують заміни, та на що звертати увагу',
    content: 'Основні ознаки зносу шин та рекомендації щодо заміни. Глибина протектора, візуальні ознаки та поради експертів.',
    category: 'safety',
    status: 'published',
    featured: true,
    reading_time: 7,
    language: 'uk'
  },
  {
    title: 'Балансування коліс: навіщо це потрібно',
    slug: 'balansuvannya-kolis',
    excerpt: 'Що таке балансування коліс, коли його робити та як це впливає на їзду',
    content: 'Детальна інформація про балансування коліс та його важливість. Ознаки дисбалансу, процес балансування та рекомендації.',
    category: 'maintenance',
    status: 'published',
    featured: false,
    reading_time: 5,
    language: 'uk'
  },
  {
    title: 'Зимова безпека на дорозі: топ-10 правил',
    slug: 'zymova-bezpeka-na-dorozi',
    excerpt: 'Основні правила безпечної їзди взимку для українських водіїв',
    content: 'Детальний перелік правил безпечної їзди в зимових умовах. Підготовка автомобіля, техніка водіння та корисні поради.',
    category: 'safety',
    status: 'published',
    featured: true,
    reading_time: 6,
    language: 'uk'
  },
  {
    title: 'Вибір всесезонних шин: переваги та недоліки',
    slug: 'vybir-vsesezonnyh-shyn',
    excerpt: 'Коли варто обрати всесезонні шини та які у них особливості',
    content: 'Аналіз переваг та недоліків всесезонних шин. Рекомендації щодо вибору для різних умов експлуатації.',
    category: 'selection',
    status: 'published',
    featured: false,
    reading_time: 5,
    language: 'uk'
  }
]

# =============================================================================
# РУССКИЕ СТАТЬИ (для русскоязычной аудитории)
# =============================================================================
puts "\n🇷🇺 Создание русских статей..."

russian_articles = [
  {
    title: 'Как выбрать зимние шины',
    slug: 'kak-vybrat-zimnie-shiny-ru',
    excerpt: 'Подробное руководство по выбору зимних шин для безопасной езды',
    content: 'Детальное руководство по выбору зимних шин. Типы шин, критерии выбора и рекомендации экспертов.',
    category: 'selection',
    status: 'published',
    featured: true,
    reading_time: 5,
    language: 'ru'
  },
  {
    title: 'Правильное давление в шинах',
    slug: 'pravilnoe-davlenie-v-shinah-ru',
    excerpt: 'Влияние давления на безопасность и расход топлива',
    content: 'Важность поддержания правильного давления в шинах. Последствия неправильного давления и рекомендации.',
    category: 'maintenance',
    status: 'published',
    featured: false,
    reading_time: 3,
    language: 'ru'
  },
  {
    title: 'Сезонное хранение шин',
    slug: 'sezonnoe-hranenie-shin-ru',
    excerpt: 'Как правильно хранить шины в межсезонье',
    content: 'Правила хранения шин в межсезонье для продления срока службы. Условия хранения и полезные советы.',
    category: 'seasonal',
    status: 'published',
    featured: false,
    reading_time: 4,
    language: 'ru'
  },
  {
    title: 'Признаки износа шин',
    slug: 'priznaki-iznosa-shin-ru',
    excerpt: 'Как определить, когда пора менять шины',
    content: 'Основные признаки износа шин и рекомендации по замене. Глубина протектора и визуальные признаки.',
    category: 'safety',
    status: 'published',
    featured: true,
    reading_time: 4,
    language: 'ru'
  },
  {
    title: 'Балансировка колес',
    slug: 'balansirovka-koles-ru',
    excerpt: 'Зачем нужна балансировка колес и как часто ее проводить',
    content: 'Важность балансировки колес для комфортной и безопасной езды. Признаки дисбаланса и рекомендации.',
    category: 'maintenance',
    status: 'published',
    featured: false,
    reading_time: 3,
    language: 'ru'
  }
]

# =============================================================================
# СОЗДАНИЕ СТАТЕЙ
# =============================================================================

def create_articles(articles, language_name)
  created_count = 0
  articles.each do |article_data|
    begin
      article = Article.create!(
        title: article_data[:title],
        slug: article_data[:slug],
        excerpt: article_data[:excerpt],
        content: article_data[:content],
        category: article_data[:category],
        status: article_data[:status],
        featured: article_data[:featured],
        reading_time: article_data[:reading_time],
        views_count: rand(50..200),
        author: User.find_by(email: 'admin@test.com'),
        published_at: Time.current - rand(30).days,
        allow_comments: true,
        meta_title: article_data[:title],
        meta_description: article_data[:excerpt],
        tags: case article_data[:language]
              when 'en' then ['tires', 'automotive', 'safety']
              when 'uk' then ['шини', 'автомобіль', 'безпека']
              when 'ru' then ['шины', 'автомобиль', 'безопасность']
              else ['general']
              end
      )
      puts "  ✅ #{article.title} (ID: #{article.id})"
      created_count += 1
    rescue => e
      puts "  ❌ Ошибка при создании '#{article_data[:title]}': #{e.message}"
    end
  end
  puts "  📊 Создано статей: #{created_count}/#{articles.length}"
  created_count
end

# Создаем статьи по языкам
english_count = create_articles(english_articles, 'English')
ukrainian_count = create_articles(ukrainian_articles, 'Ukrainian')  
russian_count = create_articles(russian_articles, 'Russian')

# =============================================================================
# ИТОГОВАЯ СТАТИСТИКА
# =============================================================================
puts "\n" + "="*50
puts "📊 ИТОГОВАЯ СТАТИСТИКА"
puts "="*50
puts "🇺🇸 Английских статей: #{english_count}"
puts "🇺🇦 Украинских статей: #{ukrainian_count}"
puts "🇷🇺 Русских статей: #{russian_count}"
puts "📚 Всего статей: #{Article.count}"
puts "✨ Опубликованных: #{Article.where(status: 'published').count}"
puts "⭐ Избранных: #{Article.where(featured: true).count}"
puts "\n📁 Статьи по категориям:"
Article.group(:category).count.each do |category, count|
  category_name = Article::CATEGORIES[category]&.dig(:name) || category
  puts "  #{category_name}: #{count}"
end
puts "="*50
puts "🎉 Многоязычная база статей создана успешно!" 