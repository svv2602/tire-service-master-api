# Create test environment booking statuses
if Rails.env.test?
  puts "Creating testing booking statuses..."
  
  # Ensure test has all required statuses
  booking_statuses = [
    { name: 'pending', description: 'Status pending', color: '#FFFFFF', sort_order: 1 },
    { name: 'confirmed', description: 'Status confirmed', color: '#FFFFFF', sort_order: 2 },
    { name: 'in_progress', description: 'Status in progress', color: '#FFFFFF', sort_order: 3 },
    { name: 'completed', description: 'Status completed', color: '#FFFFFF', sort_order: 4 },
    { name: 'canceled_by_client', description: 'Status canceled by client', color: '#FFFFFF', sort_order: 5 },
    { name: 'canceled_by_partner', description: 'Status canceled by partner', color: '#FFFFFF', sort_order: 6 },
    { name: 'no_show', description: 'Status no show', color: '#FFFFFF', sort_order: 7 }
  ]
  
  # Directly use SQL to bypass any validations or callbacks
  booking_statuses.each do |status|
    BookingStatus.find_or_create_by!(name: status[:name]) do |s|
      s.description = status[:description]
      s.color = status[:color]
      s.sort_order = status[:sort_order]
      s.is_active = true
    end
  end
  
  # Create payment statuses
  payment_statuses = [
    { name: 'pending', description: 'Payment status pending', color: '#FFFFFF', sort_order: 1 },
    { name: 'paid', description: 'Payment status paid', color: '#FFFFFF', sort_order: 2 },
    { name: 'failed', description: 'Payment status failed', color: '#FFFFFF', sort_order: 3 },
    { name: 'refunded', description: 'Payment status refunded', color: '#FFFFFF', sort_order: 4 }
  ]
  
  payment_statuses.each do |status|
    PaymentStatus.find_or_create_by!(name: status[:name]) do |s|
      s.description = status[:description]
      s.color = status[:color]
      s.sort_order = status[:sort_order]
      s.is_active = true
    end
  end
  
  puts "Test statuses created successfully!"
end
