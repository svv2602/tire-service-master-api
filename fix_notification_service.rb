# Скрипт для исправления NotificationService - убираем несуществующие поля

file_path = 'app/services/notification_service.rb'
content = File.read(file_path)

# Убираем все строки с action_url
content.gsub!(/\s*action_url: [^,\n]+,?\n/, "\n")

# Убираем все строки с expires_at
content.gsub!(/\s*expires_at: [^,\n]+,?\n/, "\n")

# Убираем лишние пустые строки
content.gsub!(/\n\s*\n\s*\n/, "\n\n")

# Записываем исправленный файл
File.write(file_path, content)

puts "✅ NotificationService исправлен - убраны несуществующие поля action_url и expires_at"
puts "📄 Файл: #{file_path}" 