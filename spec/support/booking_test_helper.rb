# This helper module provides methods to properly set up booking statuses and transitions
# for testing purposes, bypassing the AASM state machine validation issues.
module BookingTestHelper
  # Create all the necessary booking statuses if they don't exist
  def ensure_booking_statuses_exist
    # Create all required booking statuses
    %w[pending confirmed in_progress completed canceled_by_client canceled_by_partner no_show].each_with_index do |status_name, index|
      BookingStatus.find_or_create_by(
        name: status_name,
        description: "#{status_name.titleize} status",
        color: '#FFFFFF',
        is_active: true,
        sort_order: index + 1
      )
    end
    
    # Ensure payment statuses exist too
    %w[pending paid failed refunded].each_with_index do |status_name, index|
      PaymentStatus.find_or_create_by(
        name: status_name,
        description: "Payment status #{status_name}",
        color: '#FFFFFF',
        is_active: true,
        sort_order: index + 1
      )
    end
  end

  # Helper to create a booking directly with the specified status
  def create_booking_with_status(status_name, attributes = {})
    ensure_booking_statuses_exist
    
    # Make sure we have a valid region for the city
    region = attributes[:region] || create(:region)
    
    # Ensure we have a valid city with region
    city = attributes[:city] || create(:city, region: region)
    
    # Create a valid partner with a city
    partner = attributes[:partner] || create(:partner, :with_new_user)
    
    # Create a service point with the city and partner
    service_point = attributes[:service_point] || create(:service_point, city: city, partner: partner)
    
    # Create a client if not provided
    client = attributes[:client] || create(:client)
    
    # Create a car type if not provided
    car_type = attributes[:car_type] || create(:car_type)
    
    # Find the booking status
    status = BookingStatus.find_by(name: status_name)
    raise "Status '#{status_name}' not found. Available statuses: #{BookingStatus.pluck(:name).join(', ')}" unless status
    
    # Default payment status
    payment_status = PaymentStatus.find_by(name: 'pending')
    raise "PaymentStatus 'pending' not found" unless payment_status
    
    # Build attributes with explicit status_id (больше не используем slot)
    booking_attributes = {
      service_point: service_point,
      client: client,
      car_type: car_type,
      booking_date: attributes[:booking_date] || (Date.current + 1.day),
      start_time: attributes[:start_time] || Time.parse('10:00'),
      end_time: attributes[:end_time] || Time.parse('11:00'),
      status_id: status.id,
      payment_status_id: payment_status.id
    }.merge(attributes.except(:status_id, :payment_status_id, :slot, :service_post))
    
    # Create the booking with skip_validation flag
    booking = Booking.new(booking_attributes)
    booking.skip_status_validation = true
    booking.save(validate: false)
    
    # Make sure the booking is saved with the correct status by using update_columns
    booking.update_columns(
      status_id: status.id,
      payment_status_id: payment_status.id
    )
    
    # Reload to ensure all attributes are correctly loaded
    booking.reload
  end

  # Force update a booking's status ID bypassing validations
  def force_booking_status(booking, status_name)
    ensure_booking_statuses_exist
    status = BookingStatus.find_by(name: status_name)
    booking.update_columns(status_id: status.id)
    booking.reload
  end
  
  # Class method for before(:suite) hook
  def self.ensure_all_booking_statuses_exist
    # Создаем все статусы бронирования
    BookingStatus.find_or_create_by(
      name: 'pending',
      description: 'Pending status',
      color: '#FFC107',
      is_active: true,
      sort_order: 1
    )
    
    BookingStatus.find_or_create_by(
      name: 'confirmed',
      description: 'Confirmed status',
      color: '#4CAF50',
      is_active: true,
      sort_order: 2
    )
    
    BookingStatus.find_or_create_by(
      name: 'in_progress',
      description: 'In progress status',
      color: '#2196F3',
      is_active: true,
      sort_order: 3
    )
    
    BookingStatus.find_or_create_by(
      name: 'completed',
      description: 'Completed status',
      color: '#8BC34A',
      is_active: true,
      sort_order: 4
    )
    
    BookingStatus.find_or_create_by(
      name: 'canceled_by_client',
      description: 'Canceled by client status',
      color: '#F44336',
      is_active: true,
      sort_order: 5
    )
    
    BookingStatus.find_or_create_by(
      name: 'canceled_by_partner',
      description: 'Canceled by partner status',
      color: '#FF5722',
      is_active: true,
      sort_order: 6
    )
    
    BookingStatus.find_or_create_by(
      name: 'no_show',
      description: 'No show status',
      color: '#9C27B0',
      is_active: true,
      sort_order: 7
    )
  end
end

# Include this module in RSpec
RSpec.configure do |config|
  config.include BookingTestHelper
  
  # Ensure all booking statuses exist before running tests
  config.before(:suite) do
    BookingTestHelper.ensure_all_booking_statuses_exist
  end
end 