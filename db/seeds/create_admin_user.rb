puts "Creating admin role..."
admin_role = UserRole.find_or_create_by!(name: 'admin') do |role|
  role.description = 'Адміністратор системи з повними правами'
  role.is_active = true
end

puts "Creating test admin user..."
admin = User.find_or_initialize_by(email: 'admin@test.com')
admin.assign_attributes(
  password: 'admin123',
  password_confirmation: 'admin123',
  first_name: 'Admin',
  last_name: 'User',
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
  administrator = Administrator.find_or_initialize_by(user: admin)
  administrator.assign_attributes(
    position: 'System Administrator',
    access_level: 10
  )
  
  if administrator.save
    puts "Administrator profile created!"
  else
    puts "Failed to create administrator profile:"
    puts administrator.errors.full_messages.join("\n")
  end
else
  puts "Failed to create admin user:"
  puts admin.errors.full_messages.join("\n")
end
