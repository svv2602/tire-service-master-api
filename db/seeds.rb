# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Приоритетные сидеры (должны выполняться в определенном порядке)
priority_seeds = [
  'user_roles.rb',
  'test_users.rb'
]

# Сначала выполняем приоритетные сидеры
priority_seeds.each do |seed_name|
  seed_path = File.join(Rails.root, 'db', 'seeds', seed_name)
  if File.exist?(seed_path)
    puts "Loading priority seed file: #{seed_name}"
    load seed_path
  else
    puts "Warning: Priority seed file not found: #{seed_name}"
  end
end

# Затем выполняем остальные сидеры
Dir[File.join(Rails.root, 'db', 'seeds', '*.rb')].sort.each do |seed|
  seed_name = File.basename(seed)
  # Пропускаем уже выполненные приоритетные сидеры
  unless priority_seeds.include?(seed_name)
    puts "Loading seed file: #{seed_name}"
    begin
      load seed
    rescue => e
      puts "Error loading seed #{seed_name}: #{e.message}"
    end
  end
end

puts "All seeds loaded."
