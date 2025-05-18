class BookingSerializer < ActiveModel::Serializer
  attributes :id, :booking_date, :start_time, :end_time, :status, :payment_status,
             :cancellation_reason, :cancellation_comment, :total_price, :payment_method,
             :notes, :created_at, :updated_at, :car_type
  
  belongs_to :client
  belongs_to :service_point
  belongs_to :car, optional: true
  belongs_to :car_type
  has_many :booking_services
  
  def status
    # In Swagger dry run mode, or if status is nil, provide a default
    if ENV['SWAGGER_DRY_RUN'] || object.status.nil?
      pending_status = BookingStatus.find_or_create_by(
        name: 'pending',
        description: 'Pending status',
        color: '#FFC107',
        is_active: true,
        sort_order: 1
      )
      
      return {
        id: pending_status.id || 1, # Ensure we always have an integer ID for Swagger
        name: pending_status.name || 'pending',
        color: pending_status.color || '#FFC107'
      }
    end
    
    # Normal mode with valid status
    {
      id: object.status.id || 1, # Ensure we always have an integer ID for Swagger
      name: object.status.name || 'pending',
      color: object.status.color || '#FFC107'
    }
  end
  
  def payment_status
    if object.payment_status
      {
        id: object.payment_status.id,
        name: object.payment_status.name,
        color: object.payment_status.color
      }
    else
      nil
    end
  end
  
  def car_type
    if object.car_type
      {
        id: object.car_type.id,
        name: object.car_type.name,
        description: object.car_type.description
      }
    else
      nil
    end
  end

  def cancellation_reason
    if object.cancellation_reason
      {
        id: object.cancellation_reason.id,
        name: object.cancellation_reason.name
      }
    else
      nil
    end
  end
  
  def booking_services
    object.booking_services.map do |booking_service|
      {
        id: booking_service.id,
        service_id: booking_service.service_id,
        service_name: booking_service.service_name,
        price: booking_service.price,
        quantity: booking_service.quantity,
        total_price: booking_service.total_price
      }
    end
  end
end
