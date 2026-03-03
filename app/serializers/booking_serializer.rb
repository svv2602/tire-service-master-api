class BookingSerializer < ActiveModel::Serializer
  attributes :id, :client_id, :service_point_id, :car_id, :booking_date, :start_time, :end_time, 
             :status_id, :payment_status_id, :cancellation_reason_id, :cancellation_comment, 
             :total_price, :payment_method, :notes, :created_at, :updated_at, :car_type_id,
             :service_category_id, :is_service_booking,
             :status, :payment_status, :service_point, :client, :car_type, :car,
             :car_brand, :car_model, :license_plate, :service_recipient, :is_guest_booking,
             :service_category
  
  def status
    status_name = object.status || 'pending'
    status_info = object.class.status_by_name(status_name)
    
    if status_info
      {
        id: nil,
        name: status_info[:name],
        display_name: I18n.t("bookings.statuses.#{status_info[:name]}"),
        color: status_info[:color]
      }
    else
      {
        id: nil,
        name: status_name,
        display_name: I18n.t('bookings.statuses.unknown', default: status_name.humanize),
        color: '#9E9E9E'
      }
    end
  end
  
  def payment_status
    if object.payment_status
      {
        id: object.payment_status.id,
        name: object.payment_status.name,
        display_name: I18n.t("bookings.payment_statuses.#{object.payment_status.name}"),
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
        name: I18n.t("bookings.cancellation_reasons.#{object.cancellation_reason.name}")
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
        first_name: object.client.user.first_name,
        last_name: object.client.user.last_name,
        phone: object.client.user.phone,
        email: object.client.user.email
      }
    elsif object.client_id.present?
      {
        id: object.client_id,
        name: I18n.t('bookings.client.unknown', id: object.client_id),
        first_name: nil,
        last_name: nil,
        phone: nil,
        email: nil
      }
    else
      nil
    end
  end

  def service_point
    sp = cached_service_point

    if sp
      {
        id: sp.id,
        name: sp.name,
        address: sp.address,
        phone: sp.contact_phone,
        city: sp.city ? { id: sp.city.id, name: sp.city.name } : nil,
        partner_name: sp.partner&.name
      }
    else
      {
        id: object.service_point_id,
        name: I18n.t('bookings.service_point.unknown', id: object.service_point_id),
        address: nil,
        phone: nil,
        city: nil,
        partner_name: nil
      }
    end
  end

  private

  # Reuse the preloaded service_point association (loaded via includes in controller).
  # Falls back to a single query only when the association was not eager-loaded.
  def cached_service_point
    @cached_service_point ||= begin
      sp = object.service_point
      if sp.nil? && object.service_point_id.present?
        ServicePoint.includes(:city, :partner).find_by(id: object.service_point_id)
      else
        sp
      end
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

  def car_brand
    object.car_brand
  end

  def car_model
    object.car_model
  end

  def license_plate
    object.license_plate
  end

  def service_recipient
    {
      first_name: object.service_recipient_first_name,
      last_name: object.service_recipient_last_name,
      full_name: object.service_recipient_full_name,
      phone: object.service_recipient_phone,
      email: object.service_recipient_email,
      is_self_service: object.client_booking? ? object.self_service? : true
    }
  end
  
  def is_guest_booking
    object.guest_booking?
  end

  def service_category
    if object.service_category
      {
        id: object.service_category.id,
        name: object.service_category.name,
        description: object.service_category.description
      }
    else
      nil
    end
  end
end
