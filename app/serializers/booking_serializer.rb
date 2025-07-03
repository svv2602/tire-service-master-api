class BookingSerializer < ActiveModel::Serializer
  attributes :id, :client_id, :service_point_id, :car_id, :booking_date, :start_time, :end_time, 
             :status_id, :payment_status_id, :cancellation_reason_id, :cancellation_comment, 
             :total_price, :payment_method, :notes, :created_at, :updated_at, :car_type_id,
             :service_category_id,
             :status, :payment_status, :service_point, :client, :car_type, :car,
             :car_brand, :car_model, :license_plate, :service_recipient, :is_guest_booking,
             :service_category
  
  def status
    # Используем новое строковое поле status
    status_name = object.status || 'pending'
    
    # Получаем информацию о статусе из модуля BookingStatuses
    status_info = object.class.status_by_name(status_name)
    
    if status_info
      {
        id: nil, # ID больше не нужен, так как используем строковые статусы
        name: status_info[:name],
        display_name: status_info[:display_name],
        color: status_info[:color]
      }
    else
      # Fallback для неизвестных статусов
      {
        id: nil,
        name: status_name,
        display_name: status_name.humanize,
        color: '#9E9E9E'
      }
    end
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
        first_name: object.client.user.first_name,
        last_name: object.client.user.last_name,
        phone: object.client.user.phone,
        email: object.client.user.email
      }
    elsif object.client_id.present?
      {
        id: object.client_id,
        name: "Клиент ##{object.client_id}",
        first_name: nil,
        last_name: nil,
        phone: nil,
        email: nil
      }
    else
      # ✅ Для гостевых бронирований возвращаем nil
      nil
    end
  end

  def service_point
    # ✅ Улучшенная загрузка service_point с детальным логированием
    begin
      service_point_obj = object.service_point
      
      # Пытаемся загрузить через direct query если association не загружена
      if service_point_obj.nil? && object.service_point_id.present?
        Rails.logger.info "🔍 Attempting to load service_point ##{object.service_point_id} via direct query"
        service_point_obj = ServicePoint.includes(:city, :partner).find_by(id: object.service_point_id)
      end
      
      if service_point_obj
        Rails.logger.info "✅ Service point loaded: #{service_point_obj.name}"
        
        {
          id: service_point_obj.id,
          name: service_point_obj.name,
          address: service_point_obj.address,
          phone: service_point_obj.contact_phone,
          city: service_point_obj.city ? {
            id: service_point_obj.city.id,
            name: service_point_obj.city.name
          } : nil,
          partner_name: service_point_obj.partner&.name
        }
      else
        Rails.logger.warn "⚠️ Service point ##{object.service_point_id} not found, using fallback"
        {
          id: object.service_point_id,
          name: "Сервисная точка ##{object.service_point_id}",
          address: nil,
          phone: nil,
          city: nil,
          partner_name: nil
        }
      end
    rescue => e
      Rails.logger.error "❌ Error loading service_point ##{object.service_point_id}: #{e.message}"
      
      # Последняя попытка - загрузить напрямую без includes
      begin
        service_point_obj = ServicePoint.find_by(id: object.service_point_id)
        if service_point_obj
          {
            id: service_point_obj.id,
            name: service_point_obj.name || "Сервисная точка ##{service_point_obj.id}",
            address: service_point_obj.address,
            phone: service_point_obj.contact_phone,
            city: service_point_obj.city_id ? {
              id: service_point_obj.city_id,
              name: City.find_by(id: service_point_obj.city_id)&.name || "Город ##{service_point_obj.city_id}"
            } : nil,
            partner_name: service_point_obj.partner_id ? Partner.find_by(id: service_point_obj.partner_id)&.name : nil
          }
        else
          {
            id: object.service_point_id,
            name: "Сервисная точка ##{object.service_point_id}",
            address: nil,
            phone: nil,
            city: nil,
            partner_name: nil
          }
        end
      rescue => final_error
        Rails.logger.error "❌ Final fallback failed: #{final_error.message}"
        {
          id: object.service_point_id,
          name: "Сервисная точка ##{object.service_point_id}",
          address: nil,
          phone: nil,
          city: nil,
          partner_name: nil
        }
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
  
  # ✅ Новый атрибут для определения типа бронирования
  def is_guest_booking
    object.guest_booking?
  end

  # ✅ Добавляем сериализацию категории услуг
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
