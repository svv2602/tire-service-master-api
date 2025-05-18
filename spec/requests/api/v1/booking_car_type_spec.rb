require 'rails_helper'

RSpec.describe "API Booking with Car Type", type: :request do
  # Создаем все необходимые статусы заранее
  before(:all) do
    # Находим или создаем статусы бронирования и оплаты
    @pending_status = BookingStatus.find_or_create_by!(name: 'pending') do |status|
      status.description = 'Pending status'
      status.color = '#FFC107'
      status.is_active = true
      status.sort_order = 1
    end
    
    @payment_pending_status = PaymentStatus.find_or_create_by!(name: 'pending') do |status|
      status.description = 'Payment is pending'
      status.color = '#FFC107'
      status.sort_order = 1
      status.is_active = true
    end
    
    # Создаем или находим тип автомобиля SUV
    @suv_type = CarType.find_or_create_by!(name: 'SUV') do |car_type|
      car_type.description = 'Sport utility vehicle'
      car_type.is_active = true
    end
    
    puts "Setup: BookingStatus records = #{BookingStatus.count}, PaymentStatus records = #{PaymentStatus.count}"
    puts "Available booking statuses: #{BookingStatus.pluck(:id, :name)}"
  end
  
  let(:client) { create(:client) }
  let(:service_point) { create(:service_point) }
  # Используем существующий тип SUV
  let(:suv) { @suv_type }
  let(:slot) do 
    create(:schedule_slot, 
           service_point: service_point, 
           slot_date: Date.tomorrow,
           start_time: "10:00",
           end_time: "11:00",
           post_number: rand(1..999), # Рандомный post_number для уникальности
           is_available: true)
  end
  
  let(:auth_token) do
    user = client.user
    JWT.encode(
      { user_id: user.id, exp: 24.hours.from_now.to_i },
      Rails.application.credentials.secret_key_base
    )
  end
  
  it "creates a booking with a car type" do
    # Использование существующих статусов из before(:all)
    pending_status_id = @pending_status.id
    payment_pending_id = @payment_pending_status.id
    
    puts "Pending status ID: #{pending_status_id} (#{pending_status_id.class})"
    puts "Payment pending status ID: #{payment_pending_id} (#{payment_pending_id.class})"
    
    # Явно убеждаемся, что объект существует
    puts "BookingStatus exists?: #{BookingStatus.exists?(pending_status_id)}"
    
    # Подготовим данные для запроса
    booking_params = {
      booking: {
        service_point_id: service_point.id,
        car_type_id: suv.id,
        car_id: nil,
        slot_id: slot.id,
        booking_date: Date.tomorrow.to_s,
        start_time: "10:00",
        end_time: "11:00",
        status_id: pending_status_id,
        payment_status_id: payment_pending_id,
        notes: "Need SUV service"
      }
    }
    
    puts "Request booking params: #{booking_params[:booking]}"
    puts "Before request: Booking count = #{Booking.count}"
    
    post "/api/v1/clients/#{client.id}/bookings",
         params: booking_params,
         headers: { 'Authorization': "Bearer #{auth_token}" }
    
    puts "After request: Booking count = #{Booking.count}"
    puts "Response status: #{response.status}"
    puts "Response body: #{response.body}"
    
    # Если возникла ошибка, проверим как контроллер обработал параметры
    if response.status == 422
      errors = JSON.parse(response.body)["errors"]
      puts "Validation errors: #{errors.inspect}"
    end
    
    expect(response).to have_http_status(201)
    
    json = JSON.parse(response.body)
    expect(json["car_type"]["id"].to_s).to eq(suv.id.to_s) # Используем строковое сравнение для гибкости типов
    expect(json["car_type"]["name"]).to eq("SUV")
  end
end
