puts "Creating admin role..."
admin_role = UserRole.find_or_create_by!(name: 'admin')

puts "Creating test admin user..."
admin = User.find_or_initialize_by(email: 'admin@test.com')
admin.assign_attributes(
  password: 'admin',
  first_name: 'Admin',
  last_name: 'User',
  role: admin_role,
  is_active: true
)

if admin.save
  puts "Test admin user created successfully!"
  puts "Email: admin@test.com"
  puts "Password: admin"
  
  # Create administrator profile
  administrator = Administrator.find_or_create_by!(user: admin) do |a|
    a.position = 'System Administrator'
    a.access_level = 'full'
  end
  puts "Administrator profile created!"
else
  puts "Failed to create admin user:"
  puts admin.errors.full_messages.join("\n")
end
