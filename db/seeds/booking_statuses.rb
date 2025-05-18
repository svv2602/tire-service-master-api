# Create booking statuses
puts "Creating booking statuses..."
booking_statuses = [
  { 
    name: 'pending',
    description: 'Booking has been created but not confirmed',
    color: '#FFC107',
    sort_order: 1
  },
  { 
    name: 'confirmed',
    description: 'Booking has been confirmed',
    color: '#4CAF50',
    sort_order: 2
  },
  { 
    name: 'in_progress',
    description: 'Service is in progress',
    color: '#2196F3',
    sort_order: 3
  },
  { 
    name: 'completed',
    description: 'Service has been completed',
    color: '#8BC34A',
    sort_order: 4
  },
  { 
    name: 'canceled_by_client',
    description: 'Booking was canceled by client',
    color: '#F44336',
    sort_order: 5
  },
  { 
    name: 'canceled_by_partner',
    description: 'Booking was canceled by partner',
    color: '#9C27B0',
    sort_order: 6
  },
  { 
    name: 'no_show',
    description: 'Client did not show up',
    color: '#607D8B',
    sort_order: 7
  }
]

booking_statuses.each do |status|
  BookingStatus.find_or_create_by(name: status[:name]) do |bs|
    bs.description = status[:description]
    bs.color = status[:color]
    bs.sort_order = status[:sort_order]
  end
end
