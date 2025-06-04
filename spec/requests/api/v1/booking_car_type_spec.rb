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
  let(:service_point) { create(:service_point, :with_schedule) }
  let(:service) { create(:service) }
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
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end
  
  skip "creates a booking with a car type" do
    # Тест отключен - используется старая логика со schedule_slot
    # Новая система использует динамический расчет доступности без слотов
    pending "Переписать под динамическую систему доступности"
  end
end
