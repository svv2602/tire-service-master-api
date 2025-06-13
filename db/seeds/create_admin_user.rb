puts "Creating admin role..."
admin_role = UserRole.find_or_create_by(name: 'admin', description: 'Администратор системы')

puts "Creating test admin user..."
admin = User.find_or_initialize_by(email: 'admin@test.com')
admin.assign_attributes(
  password: 'admin123',
  password_confirmation: 'admin123',
  first_name: 'Admin',
  last_name: 'Test',
  phone: '+380 67 222 00 00',
  role: admin_role,
  is_active: true,
  email_verified: true,
  phone_verified: true
)

if admin.save
  puts "Test admin user created successfully!"
  puts "Email: admin@test.com"
  puts "Password: admin123"
  
  # Create administrator profile
  Administrator.find_or_create_by(user: admin)
  puts "Administrator profile created!"
else
  puts "Failed to create admin user:"
  puts admin.errors.full_messages.join(", ")
end
