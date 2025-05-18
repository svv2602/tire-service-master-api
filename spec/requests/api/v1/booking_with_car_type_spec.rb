require 'rails_helper'

RSpec.describe "BookingWithCarType", type: :request do
  before(:all) do
    # Get existing statuses instead of creating new ones
    @pending_status = BookingStatus.find_by(name: 'pending')
    
    # Create only if it doesn't exist
    if @pending_status.nil?
      @pending_status = BookingStatus.create!(
        name: 'pending',
        description: 'Booking is pending',
        color: '#FFC107',
        is_active: true,
        sort_order: 1
      )
    end
    
    @payment_pending = PaymentStatus.find_by(name: 'pending')
    
    # Create only if it doesn't exist
    if @payment_pending.nil?
      @payment_pending = PaymentStatus.create!(
        name: 'pending',
        description: 'Payment is pending',
        color: '#FFC107',
        is_active: true,
        sort_order: 1
      )
    end
    
    # Находим или создаем тип SUV
    @suv_type = CarType.find_or_create_by!(name: 'SUV') do |ct|
      ct.description = 'Sport utility vehicle'
      ct.is_active = true
    end
  end

  let(:client) { create(:client) }
  let(:service_point) { create(:service_point) }
  let(:suv) { @suv_type } # Используем существующий SUV
  let(:slot) do 
    create(:schedule_slot, 
           service_point: service_point, 
           slot_date: Date.tomorrow,
           start_time: "10:00",
           end_time: "11:00",
           post_number: rand(1..999), # Рандомный номер для уникальности
           is_available: true)
  end
  
  it "creates a booking with a car type" do
    # Создаем токен для аутентификации
    user = client.user
    token = JWT.encode(
      { user_id: user.id, exp: 24.hours.from_now.to_i },
      Rails.application.credentials.secret_key_base
    )
    
    # Проверяем наличие статусов до запроса
    expect(BookingStatus.exists?(@pending_status.id)).to be true
    expect(PaymentStatus.exists?(@payment_pending.id)).to be true
    
    # Создаем параметры для запроса
    booking_params = {
      booking: {
        service_point_id: service_point.id,
        car_type_id: suv.id,
        car_id: nil,
        booking_date: Date.tomorrow.to_s,
        start_time: "10:00",
        end_time: "11:00",
        slot_id: slot.id,
        status_id: @pending_status.id,
        payment_status_id: @payment_pending.id,
        notes: "Need SUV service"
      }
    }
    
    # Отправляем запрос на создание бронирования
    post "/api/v1/clients/#{client.id}/bookings",
         params: booking_params,
         headers: { 'Authorization': "Bearer #{token}" }
    
    # Выводим информацию о запросе и ответе
    puts "Request params: #{booking_params.inspect}"
    puts "Response status: #{response.status}"
    puts "Response body: #{response.body}"
    
    # Проверяем успешное создание
    expect(response).to have_http_status(201)
    
    # Проверяем, что car_type указан правильно
    json = JSON.parse(response.body)
    expect(json["car_type"]["id"].to_s).to eq(suv.id.to_s)
    expect(json["car_type"]["name"]).to eq("SUV")
  end
end
