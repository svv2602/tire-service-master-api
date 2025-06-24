class ReviewSerializer < ActiveModel::Serializer
  attributes :id, :rating, :comment, :partner_response, :is_published, :status, :created_at, :updated_at, :client, :service_point, :booking
  
  # Данные клиента с пользователем
  def client
    {
      id: object.client.id,
      user: object.client.user ? {
        id: object.client.user.id,
        email: object.client.user.email,
        phone: object.client.user.phone,
        first_name: object.client.user.first_name,
        last_name: object.client.user.last_name
      } : nil
    }
  end
  
  # Данные сервисной точки
  def service_point
    {
      id: object.service_point.id,
      name: object.service_point.name,
      address: object.service_point.address,
      phone: object.service_point.phone
    }
  end
  
  # Данные бронирования (если есть)
  def booking
    object.booking ? {
      id: object.booking.id,
      booking_date: object.booking.booking_date,
      start_time: object.booking.start_time,
      end_time: object.booking.end_time
    } : nil
  end
end 