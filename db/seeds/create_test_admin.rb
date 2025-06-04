# Create test admin user
puts "Creating test admin user..."

# Сначала создаем роль админа если её нет
admin_role = UserRole.find_or_create_by(name: 'admin') do |role|
  role.description = 'Administrator role'
end

admin = User.find_or_initialize_by(email: 'admin@test.com')
admin.assign_attributes(
  password: 'admin123',
  first_name: 'Admin',
  last_name: 'User',
  role_id: admin_role.id,
  is_active: true
)
admin.save!

puts "Test admin user created successfully!"
puts "Email: admin@test.com"
puts "Password: admin123"
