# Create payment statuses
puts "Creating payment statuses..."
payment_statuses = [
  { 
    name: 'pending',
    description: 'Payment is pending',
    color: '#FFC107',
    sort_order: 1
  },
  { 
    name: 'paid',
    description: 'Payment has been completed',
    color: '#4CAF50',
    sort_order: 2
  },
  { 
    name: 'failed',
    description: 'Payment has failed',
    color: '#F44336',
    sort_order: 3
  },
  { 
    name: 'refunded',
    description: 'Payment has been refunded',
    color: '#2196F3',
    sort_order: 4
  }
]

payment_statuses.each do |status|
  PaymentStatus.find_or_create_by(name: status[:name]) do |ps|
    ps.description = status[:description]
    ps.color = status[:color]
    ps.sort_order = status[:sort_order]
  end
end
