class BookingSerializer < ActiveModel::Serializer
  attributes :id, :client_id, :service_point_id, :car_id, :booking_date, :start_time, :end_time, 
             :status_id, :payment_status_id, :cancellation_reason_id, :cancellation_comment, 
             :total_price, :payment_method, :notes, :created_at, :updated_at, :car_type_id,
             :status, :payment_status, :service_point, :client, :car_type, :car
  
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

  def client
    if object.client && object.client.user
      {
        id: object.client.id,
        name: object.client.user.full_name || "#{object.client.user.first_name} #{object.client.user.last_name}",
        phone: object.client.user.phone,
        email: object.client.user.email
      }
    else
      {
        id: object.client_id,
        name: "Клиент ##{object.client_id}",
        phone: nil,
        email: nil
      }
    end
  end

  def service_point
    if object.service_point
      {
        id: object.service_point.id,
        name: object.service_point.name,
        address: object.service_point.address,
        partner_name: object.service_point.partner&.name
      }
    else
      {
        id: object.service_point_id,
        name: "Точка обслуживания ##{object.service_point_id}",
        address: nil,
        partner_name: nil
      }
    end
  end

  def car
    if object.car
      {
        id: object.car.id,
        brand: object.car.brand&.name,
        model: object.car.model&.name,
        year: object.car.year
      }
    else
      nil
    end
  end
end
