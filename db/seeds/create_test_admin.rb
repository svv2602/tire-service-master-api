# Create test admin user
puts "Creating test admin user..."

admin = User.find_or_initialize_by(email: 'admin@test.com')
admin.assign_attributes(
  password: 'admin',
  first_name: 'Admin',
  last_name: 'User',
  role: 'admin',
  is_active: true
)
admin.save!

puts "Test admin user created successfully!
Email: admin@test.com
Password: admin"
