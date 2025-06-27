# db/seeds/04_service_point_photos.rb
# Загрузка фотографий для сервисных точек

puts '=== Создание фотографий сервисных точек ==='

# Получаем все сервисные точки
service_points = ServicePoint.all

if service_points.empty?
  puts "❌ Нет сервисных точек для добавления фотографий"
  puts "   Запустите сначала seed файл service_points_improved.rb"
  exit
end

# Примеры URL фотографий (можно заменить на реальные)
photo_urls = [
  'https://images.unsplash.com/photo-1632823471565-1ecdf2d0d6e8?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1563720223185-11003d516935?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1581833971358-2c8b550f87b3?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1592853625511-ad0edcc69c07?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1606577924006-27d39b132ae2?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1572949645841-094f3f3fd847?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=800&h=600&fit=crop'
]

# Типы фотографий
photo_types = ['exterior', 'interior', 'equipment', 'workspace']

created_count = 0
updated_count = 0

service_points.each do |service_point|
  puts "  📸 Добавление фотографий для: #{service_point.name}"
  
  # Добавляем 2-3 фотографии для каждой точки
  photos_count = [2, 3].sample
  
  photos_count.times do |index|
    photo_url = photo_urls.sample
    photo_type = photo_types.sample
    
    # Проверяем, не существует ли уже такая фотография
    existing_photo = ServicePointPhoto.find_by(
      service_point: service_point,
      description: "#{photo_type.capitalize} фото #{service_point.name}"
    )
    
    if existing_photo
      # Обновляем существующую
      existing_photo.update!(
        description: "#{photo_type.capitalize} фото #{service_point.name}",
        sort_order: index + 1,
        is_main: index == 0
      )
      updated_count += 1
      puts "    ✏️  Обновлено фото: #{photo_type}"
    else
      # Создаем новую
      ServicePointPhoto.create!(
        service_point: service_point,
        description: "#{photo_type.capitalize} фото #{service_point.name}",
        sort_order: index + 1,
        is_main: index == 0
      )
      created_count += 1
      puts "    ✨ Создано фото: #{photo_type}"
    end
  end
end

puts ""
puts "📊 Результат:"
puts "  Создано новых фотографий: #{created_count}"
puts "  Обновлено существующих фотографий: #{updated_count}"
puts "  Всего фотографий в системе: #{ServicePointPhoto.count}"

# Статистика по сервисным точкам
puts ""
puts "📈 Фотографии по сервисным точкам:"
ServicePoint.includes(:service_point_photos).each do |sp|
  photos_count = sp.service_point_photos.count
  primary_photo = sp.service_point_photos.find_by(is_main: true)
  puts "  #{sp.name}: #{photos_count} фото#{primary_photo ? ' (есть главное)' : ' (нет главного)'}"
end

puts ""
puts "✅ Фотографии сервисных точек успешно созданы/обновлены!" 