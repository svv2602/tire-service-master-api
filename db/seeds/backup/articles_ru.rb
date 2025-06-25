# Русские статьи для базы знаний
puts "Создание русских статей для базы знаний..."

# Получаем автора (админа) - используем простой способ
admin_user = User.where(email: 'admin@test.com').first
unless admin_user
  puts "Ошибка: Не найден пользователь admin@test.com"
  exit
end

# Русские статьи
articles_ru = [
  {
    title: 'Как выбрать зимние шины',
    content: 'Подробное руководство по выбору зимних шин для безопасной езды в холодное время года.',
    excerpt: 'Подробное руководство по выбору зимних шин для безопасной езды',
    category: 'selection',
    reading_time: 5,
    slug: 'kak-vybrat-zimnie-shiny-ru'
  },
  {
    title: 'Правильное давление в шинах',
    content: 'Влияние давления в шинах на безопасность, расход топлива и износ резины.',
    excerpt: 'Влияние давления на безопасность и расход топлива',
    category: 'maintenance',
    reading_time: 3,
    slug: 'pravilnoe-davlenie-v-shinah-ru'
  },
  {
    title: 'Сезонное хранение шин',
    content: 'Как правильно хранить шины в межсезонье, чтобы продлить их срок службы.',
    excerpt: 'Как правильно хранить шины в межсезонье',
    category: 'seasonal',
    reading_time: 4,
    slug: 'sezonnoe-hranenie-shin-ru'
  },
  {
    title: 'Признаки износа шин',
    content: 'Как определить, когда пора менять шины. Основные признаки критического износа.',
    excerpt: 'Как определить, когда пора менять шины',
    category: 'safety',
    reading_time: 4,
    slug: 'priznaki-iznosa-shin-ru'
  },
  {
    title: 'Балансировка колес',
    content: 'Зачем нужна балансировка колес и как часто ее следует проводить.',
    excerpt: 'Зачем нужна балансировка колес и как часто ее проводить',
    category: 'maintenance',
    reading_time: 3,
    slug: 'balansirovka-koles-ru'
  }
]

# Удаляем существующие русские статьи
Article.where('slug LIKE ?', '%-ru').destroy_all

articles_ru.each do |article_data|
  Article.create!(
    title: article_data[:title],
    content: article_data[:content],
    excerpt: article_data[:excerpt],
    category: article_data[:category],
    reading_time: article_data[:reading_time],
    slug: article_data[:slug],
    status: 'published',
    featured: true,
    author: admin_user,
    published_at: Time.current - rand(30).days,
    views_count: rand(100..500),
    allow_comments: true,
    meta_title: article_data[:title],
    meta_description: article_data[:excerpt],
    tags: [article_data[:category], 'Шины', 'Автомобиль']
  )
end

puts "Русские статьи созданы успешно!"
puts "Создано #{Article.where('slug LIKE ?', '%-ru').count} статей" 