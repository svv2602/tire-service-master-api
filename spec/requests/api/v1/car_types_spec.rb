require 'rails_helper'

RSpec.describe "API Car Types", type: :request do
  # Находим или создаем типы автомобилей перед всеми тестами
  before(:all) do
    # Находим или создаем типы автомобилей
    @sedan_type = CarType.find_or_create_by!(name: 'Sedan') do |ct|
      ct.description = 'Standard sedan car'
      ct.is_active = true
    end
    
    @suv_type = CarType.find_or_create_by!(name: 'SUV') do |ct|
      ct.description = 'Sport utility vehicle'
      ct.is_active = true
    end
    
    # Находим или создаем статусы
    @pending_status = BookingStatus.find_or_create_by!(name: 'pending') do |bs|
      bs.description = 'Booking has been created but not confirmed'
      bs.color = '#FFC107'
      bs.sort_order = 1
      bs.is_active = true
    end
    
    @payment_pending = PaymentStatus.find_or_create_by!(name: 'pending') do |ps|
      ps.description = 'Payment is pending'
      ps.color = '#FFC107'
      ps.sort_order = 1
      ps.is_active = true
    end
  end
  
  # Используем существующие объекты вместо создания новых
  let(:sedan) { @sedan_type }
  let(:suv) { @suv_type }
  let(:pending_status) { @pending_status }
  let(:payment_pending) { @payment_pending }
  
  let!(:client) { create(:client) }
  let!(:user) { client.user }
  let!(:service_point) { create(:service_point, :with_schedule) }
  let!(:service) { create(:service) }
  
  let!(:token) do
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end
  
  let!(:slot) do 
    create(:schedule_slot, 
           service_point: service_point, 
           slot_date: Date.tomorrow,
           start_time: "10:00",
           end_time: "11:00",
           post_number: rand(1..999), # Используем случайный номер для уникальности
           is_available: true)
  end
  
  describe "GET /api/v1/car_types" do
    it "returns all car types" do
      get "/api/v1/car_types", headers: { 'Authorization': "Bearer #{token}" }
      
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json.length).to be >= 2 # Может быть больше 2-х из-за других тестов
      expect(json.map { |ct| ct["name"] }).to include('Sedan', 'SUV')
    end
  end
  
  describe "POST /api/v1/clients/:client_id/bookings with car_type" do
    skip "creates a booking with a car type instead of a specific car" do
      # Тест отключен - используется старая логика со schedule_slot
      # Новая система использует динамический расчет доступности без слотов
      pending "Переписать под динамическую систему доступности"
    end
  end
  
  skip "POST /api/v1/car_types/:id/calculate_price returns correct pricing for SUV" do
    # Тест отключен - используется старая логика со schedule_slot
    # Новая система использует динамический расчет доступности без слотов
    pending "Переписать под динамическую систему доступности"
  end
end
