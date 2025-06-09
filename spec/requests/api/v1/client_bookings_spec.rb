require 'rails_helper'

RSpec.describe "Api::V1::ClientBookings", type: :request do
  let!(:region) { create(:region, name: 'Киевская область') }
  let!(:city) { create(:city, name: 'Киев', region: region) }
  let!(:partner) { create(:partner, :with_new_user) }
  let!(:service_point) do 
    create(:service_point, 
           name: 'ШиноСервис Центр',
           city: city,
           partner: partner,
           is_active: true,
           work_status: 'working',
           post_count: 4)
  end
  let!(:car_type) { create(:car_type, name: 'Легковой автомобиль') }
  let!(:booking_status) { create(:booking_status, name: 'pending') }
  let!(:canceled_status) { create(:booking_status, name: 'canceled_by_client') }
  let!(:client_role) { create(:user_role, name: 'client', description: 'Client role') }
  
  # Создаем расписание для сервисной точки (пн-сб рабочие дни)
  before do
    # Создаем дни недели используя правильные поля
    weekdays_data = [
      { name: 'Monday', short_name: 'Mon', sort_order: 1 },
      { name: 'Tuesday', short_name: 'Tue', sort_order: 2 },
      { name: 'Wednesday', short_name: 'Wed', sort_order: 3 },
      { name: 'Thursday', short_name: 'Thu', sort_order: 4 },
      { name: 'Friday', short_name: 'Fri', sort_order: 5 },
      { name: 'Saturday', short_name: 'Sat', sort_order: 6 },
      { name: 'Sunday', short_name: 'Sun', sort_order: 7 }
    ]
    
    weekdays_data.each do |day_data|
      weekday = Weekday.find_or_create_by(sort_order: day_data[:sort_order]) do |w|
        w.name = day_data[:name]
        w.short_name = day_data[:short_name]
      end
      
      # Создаем шаблон расписания (пн-сб рабочие, вс - выходной)
      is_working = day_data[:sort_order] != 7
      
      create(:schedule_template, 
             service_point: service_point,
             weekday: weekday,
             is_working_day: is_working,
             opening_time: is_working ? Time.parse('09:00') : Time.parse('00:00'),
             closing_time: is_working ? Time.parse('18:00') : Time.parse('23:59'))
    end
  end
  
  describe 'POST /api/v1/client_bookings' do
    let(:tomorrow) { Date.current + 1.day }
    
    let(:valid_params) do
      {
        client: {
          first_name: 'Иван',
          last_name: 'Иванов',
          phone: '+380671234567',
          email: 'ivan@example.com'
        },
        car: {
          license_plate: 'АА1234ВВ',
          car_brand: 'Toyota',
          car_model: 'Camry',
          year: 2020
        },
        booking: {
          service_point_id: service_point.id,
          booking_date: tomorrow.to_s,
          start_time: '10:00',
          notes: 'Замена летней резины'
        }
      }
    end
    
    context 'с валидными данными' do
      it 'создает новое бронирование' do
        initial_count = Booking.count
        
        post '/api/v1/client_bookings', params: valid_params, as: :json
        
        puts "Response status: #{response.status}"
        puts "Response body: #{response.body}"
        
        expect(Booking.count).to eq(initial_count + 1)
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['booking_date']).to eq(tomorrow.to_s)
        expect(json_response['start_time']).to eq('10:00')
        expect(json_response['client']['name']).to eq('Иван Иванов')
        expect(json_response['car_info']['license_plate']).to eq('АА1234ВВ')
        expect(json_response['status']['name']).to eq('pending')
      end
      
      it 'создает клиента если он не существует' do
        expect {
          post '/api/v1/client_bookings', params: valid_params, as: :json
        }.to change(Client, :count).by(1)
        
        created_client = Client.last
        expect(created_client.user.first_name).to eq('Иван')
        expect(created_client.user.phone).to eq('+380671234567')
      end
      
      it 'находит существующего клиента по email' do
        existing_user = create(:user, email: 'ivan@example.com', first_name: 'Иван')
        existing_client = create(:client, user: existing_user)
        
        expect {
          post '/api/v1/client_bookings', params: valid_params, as: :json
        }.not_to change(Client, :count)
        
        json_response = JSON.parse(response.body)
        expect(json_response['client']['name']).to eq('Иван ')
      end
      
      it 'создает тип автомобиля на основе переданных данных' do
        post '/api/v1/client_bookings', params: valid_params, as: :json
        
        expect(response).to have_http_status(:created)
        expect(CarType.find_by(name: 'Toyota Camry')).to be_present
      end
    end
    
    context 'с невалидными данными' do
      it 'возвращает ошибку если не указано имя клиента' do
        invalid_params = valid_params.deep_dup
        invalid_params[:client][:first_name] = ''
        
        post '/api/v1/client_bookings', params: invalid_params, as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['details']).to include('Имя клиента обязательно')
      end
      
      it 'возвращает ошибку если не указан номер автомобиля' do
        invalid_params = valid_params.deep_dup
        invalid_params[:car][:license_plate] = ''
        
        post '/api/v1/client_bookings', params: invalid_params, as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['details']).to include('Номер автомобиля обязателен')
      end
      
      it 'возвращает ошибку если время недоступно' do
        # Создаем существующее бронирование на это время
        create(:booking, 
               service_point: service_point,
               booking_date: tomorrow,
               start_time: '10:00',
               end_time: '11:00',
               status: booking_status)
        
        # Устанавливаем posts_count = 1 чтобы занять всю доступность
        service_point.update(post_count: 1)
        
        post '/api/v1/client_bookings', params: valid_params, as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Выбранное время недоступно')
      end
    end
  end
  
  describe 'POST /api/v1/client_bookings/check_availability_for_booking' do
    let(:tomorrow) { Date.current + 1.day }
    
    let(:check_params) do
      {
        service_point_id: service_point.id,
        date: tomorrow.to_s,
        time: '10:00',
        duration_minutes: 60
      }
    end
    
    it 'возвращает доступность для свободного времени' do
      post '/api/v1/client_bookings/check_availability_for_booking', params: check_params, as: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['available']).to be true
      expect(json_response['total_posts']).to eq(4)
      expect(json_response['occupied_posts']).to eq(0)
      expect(json_response['available_posts']).to eq(4)
    end
    
    it 'возвращает недоступность для занятого времени' do
      # Создаем бронирования на все посты
      service_point.post_count.times do |i|
        create(:booking,
               service_point: service_point,
               booking_date: tomorrow,
               start_time: '10:00',
               end_time: '11:00',
               status: booking_status)
      end
      
      post '/api/v1/client_bookings/check_availability_for_booking', params: check_params, as: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['available']).to be false
      expect(json_response['reason']).to include('заняты')
    end
    
    it 'возвращает ошибку для обязательных параметров' do
      post '/api/v1/client_bookings/check_availability_for_booking', params: {}, as: :json
      
      expect(response).to have_http_status(:bad_request)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('service_point_id обязателен')
    end
  end
  
  describe 'GET /api/v1/client_bookings/:id' do
    let!(:client) { create(:client) }
    let!(:booking) do
      create(:booking,
             client: client,
             service_point: service_point,
             car_type: car_type,
             status: booking_status)
    end
    
    it 'возвращает информацию о записи' do
      get "/api/v1/client_bookings/#{booking.id}", as: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['id']).to eq(booking.id)
      expect(json_response['client']['name']).to include(client.user.first_name)
      expect(json_response['service_point']['name']).to eq(service_point.name)
    end
    
    it 'возвращает 404 для несуществующей записи' do
      get '/api/v1/client_bookings/999999', as: :json
      
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Запись не найдена')
    end
  end
  
  describe 'PUT /api/v1/client_bookings/:id' do
    let!(:client) { create(:client) }
    let!(:booking) do
      create(:booking,
             client: client,
             service_point: service_point,
             car_type: car_type,
             status: booking_status,
             booking_date: Date.current + 1.day,
             start_time: '10:00')
    end
    
    let(:update_params) do
      {
        booking: {
          booking_date: (Date.current + 2.days).to_s,
          start_time: '11:00',
          notes: 'Обновленные заметки'
        }
      }
    end
    
    it 'обновляет запись в статусе pending' do
      put "/api/v1/client_bookings/#{booking.id}", params: update_params, as: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['booking_date']).to eq((Date.current + 2.days).to_s)
      expect(json_response['start_time']).to eq('11:00')
      expect(json_response['notes']).to eq('Обновленные заметки')
    end
    
    it 'запрещает обновление подтвержденной записи' do
      confirmed_status = create(:booking_status, name: 'confirmed')
      booking.update(status: confirmed_status)
      
      put "/api/v1/client_bookings/#{booking.id}", params: update_params, as: :json
      
      expect(response).to have_http_status(:forbidden)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('нельзя изменить')
    end
  end
  
  describe 'DELETE /api/v1/client_bookings/:id/cancel' do
    let!(:client) { create(:client) }
    let!(:booking) do
      create(:booking,
             client: client,
             service_point: service_point,
             car_type: car_type,
             status: booking_status,
             booking_date: Date.current + 1.day,
             start_time: '10:00')
    end
    
    it 'отменяет запись в статусе pending' do
      delete "/api/v1/client_bookings/#{booking.id}/cancel", as: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['status']['name']).to eq('canceled_by_client')
      
      booking.reload
      expect(booking.status.name).to eq('canceled_by_client')
    end
    
    it 'запрещает отмену слишком близко к времени записи' do
      # Устанавливаем время записи через час
      booking.update(
        booking_date: Date.current,
        start_time: (Time.current + 1.hour).strftime('%H:%M')
      )
      
      delete "/api/v1/client_bookings/#{booking.id}/cancel", as: :json
      
      expect(response).to have_http_status(:forbidden)
      json_response = JSON.parse(response.body)
      expect(json_response['reason']).to include('за 2 часа')
    end
  end
  
  describe 'POST /api/v1/client_bookings/:id/reschedule' do
    let!(:client) { create(:client) }
    let!(:booking) do
      create(:booking,
             client: client,
             service_point: service_point,
             car_type: car_type,
             status: booking_status,
             booking_date: Date.current + 1.day,
             start_time: '10:00',
             end_time: '11:00')
    end
    
    let(:reschedule_params) do
      {
        new_date: (Date.current + 3.days).to_s,
        new_time: '14:00'
      }
    end
    
    it 'переносит запись на новое время' do
      post "/api/v1/client_bookings/#{booking.id}/reschedule", params: reschedule_params, as: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['booking_date']).to eq((Date.current + 3.days).to_s)
      expect(json_response['start_time']).to eq('14:00')
      
      booking.reload
      expect(booking.booking_date).to eq(Date.current + 3.days)
      expect(booking.start_time.strftime('%H:%M')).to eq('14:00')
    end
    
    it 'запрещает перенос на недоступное время' do
      # Создаем бронирование на новое время
      create(:booking,
             service_point: service_point,
             booking_date: Date.current + 3.days,
             start_time: '14:00',
             end_time: '15:00',
             status: booking_status)
      
      # Устанавливаем posts_count = 1 чтобы занять всю доступность
      service_point.update(post_count: 1)
      
      post "/api/v1/client_bookings/#{booking.id}/reschedule", params: reschedule_params, as: :json
      
      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Новое время недоступно')
    end
    
    it 'возвращает ошибку для обязательных параметров' do
      post "/api/v1/client_bookings/#{booking.id}/reschedule", params: {}, as: :json
      
      expect(response).to have_http_status(:bad_request)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('new_date обязательна')
    end
  end
end 