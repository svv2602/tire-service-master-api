# This file ensures that booking statuses are available in the test database
RSpec.configure do |config|
  config.before(:suite) do
    # Create booking statuses if they don't exist
    booking_statuses = [
      { name: 'pending', description: 'Booking has been created but not confirmed', color: '#FFC107', is_active: true, sort_order: 1 },
      { name: 'confirmed', description: 'Booking has been confirmed by the service point', color: '#4CAF50', is_active: true, sort_order: 2 },
      { name: 'in_progress', description: 'Service is currently being provided', color: '#2196F3', is_active: true, sort_order: 3 },
      { name: 'completed', description: 'Service has been successfully completed', color: '#8BC34A', is_active: true, sort_order: 4 },
      { name: 'canceled_by_client', description: 'Booking was canceled by the client', color: '#F44336', is_active: true, sort_order: 5 },
      { name: 'canceled_by_partner', description: 'Booking was canceled by the partner', color: '#FF5722', is_active: true, sort_order: 6 },
      { name: 'no_show', description: 'Client did not show up', color: '#9C27B0', is_active: true, sort_order: 7 }
    ]

    booking_statuses.each do |attrs|
      BookingStatus.find_or_create_by!(name: attrs[:name]) do |status|
        status.assign_attributes(attrs)
      end
    end

    # Create payment statuses if they don't exist
    payment_statuses = [
      { name: 'pending', description: 'Payment is expected', color: '#FFC107', is_active: true, sort_order: 1 },
      { name: 'paid', description: 'Payment has been successfully processed', color: '#4CAF50', is_active: true, sort_order: 2 },
      { name: 'failed', description: 'Payment attempt failed', color: '#F44336', is_active: true, sort_order: 3 },
      { name: 'refunded', description: 'Payment has been refunded', color: '#2196F3', is_active: true, sort_order: 4 },
      { name: 'partially_refunded', description: 'Payment has been partially refunded', color: '#9C27B0', is_active: true, sort_order: 5 }
    ]

    payment_statuses.each do |attrs|
      PaymentStatus.find_or_create_by!(name: attrs[:name]) do |status|
        status.assign_attributes(attrs)
      end
    end
  end
end
