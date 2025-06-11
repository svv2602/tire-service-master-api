# db/seeds/user_roles.rb
# Створення тестових даних для ролей користувачів

puts 'Creating user roles...'

# Очищення існуючих записів
UserRole.destroy_all

# Дані ролей користувачів
roles_data = [
  {
    id: 1,
    name: 'admin',
    description: 'Адміністратор системи з повними правами',
    is_active: true
  },
  {
    id: 2,
    name: 'manager',
    description: 'Менеджер партнера з правами управління сервісними точками',
    is_active: true
  },
  {
    id: 3,
    name: 'operator',
    description: 'Оператор сервісної точки',
    is_active: true
  },
  {
    id: 4,
    name: 'partner',
    description: 'Партнер з правами управління своїми сервісними точками',
    is_active: true
  },
  {
    id: 5,
    name: 'client',
    description: 'Клієнт системи',
    is_active: true
  }
]

# Створення ролей
roles_data.each do |role_data|
  role = UserRole.find_or_initialize_by(id: role_data[:id])
  role.update!(role_data)
  puts "  Created user role: #{role.name}"
end

puts "Created #{UserRole.count} user roles successfully!" 