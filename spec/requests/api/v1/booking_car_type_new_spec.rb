require 'rails_helper'

RSpec.describe "API Booking with Car Type", type: :request do
  # Создаем или находим SUV car_type перед всеми тестами
  before(:all) do
    @suv_type = CarType.find_or_create_by!(name: 'SUV') do |car_type|
      car_type.description = 'Sport utility vehicle'
      car_type.is_active = true
    end
  end
  
  let(:client) { create(:client) }
  let(:service_point) { create(:service_point) }
  let(:suv) { @suv_type } # Используем существующий car_type
  
  let(:auth_token) do
    user = client.user
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end
  
  it "creates a booking with a car type" do
    # Убедимся, что у нас есть необходимые статусы
    booking_status = BookingStatus.find_or_create_by(name: 'pending') do |status|
      status.description = 'Pending status'
      status.color = '#FFC107'
      status.is_active = true
      status.sort_order = 1
    end
    
    payment_status = PaymentStatus.find_or_create_by(name: 'pending') do |status|
      status.description = 'Payment pending'
      status.color = '#FFC107'
      status.sort_order = 1
      status.is_active = true
    end
    
    # Создаем бронирование с использованием типа автомобиля (новая система без слотов)
    booking_date = Date.tomorrow
    start_time = Time.parse("#{booking_date} 10:00")
    end_time = Time.parse("#{booking_date} 11:00")
    
    booking = Booking.new(
      client: client,
      service_point: service_point,
      car_type: suv,
      booking_date: booking_date,
      start_time: start_time,
      end_time: end_time,
      status_id: booking_status.id,
      payment_status_id: payment_status.id,
      notes: "Need SUV service"
    )
    
    # Пропускаем валидации доступности для тестовых данных
    booking.skip_availability_check = true
    booking.save!
    
    # Проверяем API для получения созданного бронирования
    get "/api/v1/bookings/#{booking.id}",
         headers: { 'Authorization': "Bearer #{auth_token}" }
         
    expect(response).to have_http_status(200)
    
    json = JSON.parse(response.body)
    expect(json["car_type"]["id"].to_s).to eq(suv.id.to_s)
    expect(json["car_type"]["name"]).to eq("SUV")
  end
end
