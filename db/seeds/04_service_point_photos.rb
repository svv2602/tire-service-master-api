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

# Локальные файлы изображений из папки public/image
local_image_files = [
  Rails.root.join('public', 'image', '1.jpeg').to_s,
  Rails.root.join('public', 'image', '2.jpeg').to_s,
  Rails.root.join('public', 'image', '3.jpeg').to_s,
  Rails.root.join('public', 'image', '4.jpeg').to_s,
  Rails.root.join('public', 'image', 'img_calc.png').to_s
]

# Проверяем доступность файлов
available_files = local_image_files.select { |file| File.exist?(file) }

if available_files.empty?
  puts "⚠️  Локальные файлы изображений не найдены"
  puts "   Пропускаем создание фотографий"
  puts "   Файлы искались в: #{local_image_files.join(', ')}"
  exit
end

puts "📁 Найдено изображений: #{available_files.count}"
puts "📁 Доступные файлы: #{available_files.map { |f| File.basename(f) }.join(', ')}"

# Типы фотографий
photo_types = ['exterior', 'interior', 'equipment', 'workspace']

created_count = 0
updated_count = 0

service_points.each do |service_point|
  puts "  📸 Добавление фотографий для: #{service_point.name}"
  
  # Добавляем 2-3 фотографии для каждой точки
  photos_count = [2, 3].sample
  
  photos_count.times do |index|
    image_file = available_files.sample
    photo_type = photo_types.sample
    
    # Проверяем, не существует ли уже такая фотография
    existing_photo = ServicePointPhoto.find_by(
      service_point: service_point,
      description: "#{photo_type.capitalize} фото #{service_point.name}"
    )
    
    if existing_photo
      # Обновляем существующую (без файла, только метаданные)
      existing_photo.update!(
        description: "#{photo_type.capitalize} фото #{service_point.name}",
        sort_order: index + 1,
        is_main: index == 0
      )
      updated_count += 1
      puts "    ✏️  Обновлено фото: #{photo_type}"
    else
      # Создаем новую запись с прикреплением файла
      begin
        photo = ServicePointPhoto.new(
          service_point: service_point,
          description: "#{photo_type.capitalize} фото #{service_point.name}",
          sort_order: index + 1,
          is_main: index == 0
        )
        
        # Прикрепляем файл изображения
        photo.file.attach(
          io: File.open(image_file),
          filename: File.basename(image_file),
          content_type: case File.extname(image_file).downcase
                       when '.jpg', '.jpeg' then 'image/jpeg'
                       when '.png' then 'image/png'
                       else 'image/jpeg'
                       end
        )
        
        photo.save!
        created_count += 1
        puts "    ✨ Создано фото: #{photo_type} (#{File.basename(image_file)})"
      rescue => e
        puts "    ❌ Ошибка создания фото #{photo_type}: #{e.message}"
      end
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
ServicePoint.includes(:photos).each do |sp|
  photos_count = sp.photos.count
  primary_photo = sp.photos.find_by(is_main: true)
  puts "  #{sp.name}: #{photos_count} фото#{primary_photo ? ' (есть главное)' : ' (нет главного)'}"
end

puts ""
puts "✅ Фотографии сервисных точек успешно созданы/обновлены!" 