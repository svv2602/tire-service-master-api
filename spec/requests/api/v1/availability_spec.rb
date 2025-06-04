require 'rails_helper'

RSpec.describe "Api::V1::Availability", type: :request do
  let!(:service_point) { create(:service_point, post_count: 3) }
  let!(:service_posts) do
    3.times.map do |i|
      create(:service_post, 
        service_point: service_point,
        post_number: i + 1,
        slot_duration: 60,
        is_active: true
      )
    end
  end
  
  let!(:weekday) { create(:weekday, name: 'Tuesday', sort_order: 2) }
  let!(:schedule_template) do
    create(:schedule_template,
      service_point: service_point,
      weekday: weekday,
      is_working_day: true,
      opening_time: '09:00:00',
      closing_time: '18:00:00'
    )
  end
  
  let!(:client) { create(:client) }
  let!(:car_type) { create(:car_type) }
  let!(:pending_status) { create(:booking_status, name: 'pending') }
  
  let(:test_date) { '2025-06-03' } # Tuesday
  let(:headers) { { 'Content-Type' => 'application/json' } }
  
  describe 'GET /api/v1/service_points/:service_point_id/availability/:date' do
    let(:path) { "/api/v1/service_points/#{service_point.id}/availability/#{test_date}" }
    
    context 'без бронирований' do
      it 'возвращает все доступные временные интервалы' do
        get path, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['service_point_id']).to eq(service_point.id)
        expect(json['date']).to eq(test_date)
        expect(json['available_times']).to be_an(Array)
        expect(json['available_times'].count).to eq(36) # 9 часов * 4 интервала
        expect(json['available_times'].first['time']).to eq('09:00')
        expect(json['available_times'].first['available_posts']).to eq(3)
      end
    end
    
    context 'с параметром duration' do
      it 'возвращает слоты для указанной длительности' do
        get path, params: { duration: 60 }, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['duration']).to eq(60)
        expect(json['available_times']).to be_an(Array)
        # Последний слот должен позволять разместить 60-минутное бронирование
        expect(json['available_times'].last['time']).to eq('17:00')
      end
    end
    
    context 'с существующими бронированиями' do
      before do
        create(:booking,
          service_point: service_point,
          client: client,
          car_type: car_type,
          status: pending_status,
          booking_date: Date.parse(test_date),
          start_time: DateTime.new(2025, 6, 3, 10, 0, 0),
          end_time: DateTime.new(2025, 6, 3, 11, 0, 0),
          skip_availability_check: true,
          skip_status_validation: true
        )
      end
      
      it 'учитывает занятые посты' do
        get path, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        slot_10_00 = json['available_times'].find { |slot| slot['time'] == '10:00' }
        expect(slot_10_00['available_posts']).to eq(2) # 3 - 1 занятый
        
        slot_09_00 = json['available_times'].find { |slot| slot['time'] == '09:00' }
        expect(slot_09_00['available_posts']).to eq(3) # все свободны
      end
    end
    
    context 'нерабочий день' do
      let(:sunday_date) { '2025-06-01' } # Sunday
      let(:sunday_path) { "/api/v1/service_points/#{service_point.id}/availability/#{sunday_date}" }
      
      it 'возвращает пустой массив' do
        get sunday_path, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['available_times']).to be_empty
        expect(json['is_working_day']).to be false
      end
    end
    
    context 'несуществующая точка обслуживания' do
      let(:invalid_path) { "/api/v1/service_points/99999/availability/#{test_date}" }
      
      it 'возвращает ошибку 404' do
        get invalid_path, headers: headers
        
        expect(response).to have_http_status(:not_found)
      end
    end
  end
  
  describe 'POST /api/v1/service_points/:service_point_id/availability/check' do
    let(:path) { "/api/v1/service_points/#{service_point.id}/availability/check" }
    
    context 'проверка доступного времени' do
      let(:valid_params) do
        {
          date: test_date,
          time: '10:00',
          duration_minutes: 60
        }
      end
      
      it 'возвращает доступность' do
        post path, params: valid_params.to_json, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['available']).to be true
        expect(json['total_posts']).to eq(3)
        expect(json['occupied_posts']).to eq(0)
        expect(json['time']).to eq('10:00')
        expect(json['duration_minutes']).to eq(60)
      end
    end
    
    context 'проверка занятого времени' do
      before do
        # Занимаем все посты
        3.times do
          create(:booking,
            service_point: service_point,
            client: client,
            car_type: car_type,
            status: pending_status,
            booking_date: Date.parse(test_date),
            start_time: DateTime.new(2025, 6, 3, 10, 0, 0),
            end_time: DateTime.new(2025, 6, 3, 11, 0, 0),
            skip_availability_check: true,
            skip_status_validation: true
          )
        end
      end
      
      let(:busy_params) do
        {
          date: test_date,
          time: '10:00',
          duration_minutes: 60
        }
      end
      
      it 'возвращает недоступность' do
        post path, params: busy_params.to_json, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['available']).to be false
        expect(json['reason']).to include('заняты')
      end
    end
    
    context 'проверка вне рабочих часов' do
      let(:invalid_time_params) do
        {
          date: test_date,
          time: '08:00',
          duration_minutes: 60
        }
      end
      
      it 'возвращает недоступность' do
        post path, params: invalid_time_params.to_json, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['available']).to be false
        expect(json['reason']).to eq('Вне рабочих часов')
      end
    end
    
    context 'невалидные параметры' do
      it 'возвращает ошибку при отсутствии обязательных параметров' do
        post path, params: {}.to_json, headers: headers
        
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        
        expect(json['error']).to be_present
      end
    end
  end
  
  describe 'GET /api/v1/service_points/:service_point_id/availability/:date/next' do
    let(:path) { "/api/v1/service_points/#{service_point.id}/availability/#{test_date}/next" }
    
    context 'поиск следующего доступного времени' do
      it 'находит ближайшее доступное время' do
        get path, params: { after_time: '10:00', duration: 60 }, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['next_available_time']).to be_present
        expect(json['next_available_time']['time']).to eq('10:00')
        expect(json['next_available_time']['available_posts']).to eq(3)
      end
    end
    
    context 'когда весь день занят' do
      before do
        # Создаем расписание для всех дней недели
        (1..7).each do |day|
          weekday = create(:weekday, name: "Day#{day}", sort_order: day)
          create(:schedule_template,
            service_point: service_point,
            weekday: weekday,
            is_working_day: true, # Все дни рабочие
            opening_time: '09:00:00',
            closing_time: '18:00:00'
          )
        end
        
        # Занимаем много дней подряд (текущий день + следующие 35 дней)
        (0..35).each do |day_offset|
          booking_date = Date.parse(test_date) + day_offset.days
          (9..17).each do |hour|
            3.times do
              create(:booking,
                service_point: service_point,
                client: client,
                car_type: car_type,
                status: pending_status,
                booking_date: booking_date,
                start_time: DateTime.new(booking_date.year, booking_date.month, booking_date.day, hour, 0, 0),
                end_time: DateTime.new(booking_date.year, booking_date.month, booking_date.day, hour + 1, 0, 0),
                skip_availability_check: true,
                skip_status_validation: true
              )
            end
          end
        end
      end
      
      it 'возвращает информацию об отсутствии доступного времени' do
        get path, params: { after_time: '10:00', duration: 60 }, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['next_available_time']).to be_nil
        expect(json['message']).to include('доступных времён')
      end
    end
  end
  
  describe 'GET /api/v1/service_points/:service_point_id/availability/:date/details' do
    let(:path) { "/api/v1/service_points/#{service_point.id}/availability/#{test_date}/details" }
    
    context 'детальная информация о загрузке дня' do
      before do
        create(:booking,
          service_point: service_point,
          client: client,
          car_type: car_type,
          status: pending_status,
          booking_date: Date.parse(test_date),
          start_time: DateTime.new(2025, 6, 3, 10, 0, 0),
          end_time: DateTime.new(2025, 6, 3, 11, 0, 0),
          skip_availability_check: true,
          skip_status_validation: true
        )
      end
      
      it 'возвращает детальную информацию' do
        get path, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['service_point_id']).to eq(service_point.id)
        expect(json['date']).to eq(test_date)
        expect(json['is_working']).to be true
        expect(json['opening_time']).to eq('09:00')
        expect(json['closing_time']).to eq('18:00')
        expect(json['total_posts']).to eq(3)
        expect(json['intervals']).to be_an(Array)
        expect(json['intervals'].count).to eq(36)
        
        # Проверяем конкретные интервалы
        slot_09_00 = json['intervals'].find { |i| i['time'] == '09:00' }
        expect(slot_09_00['occupied_posts']).to eq(0)
        expect(slot_09_00['available_posts']).to eq(3)
        
        slot_10_00 = json['intervals'].find { |i| i['time'] == '10:00' }
        expect(slot_10_00['occupied_posts']).to eq(1)
        expect(slot_10_00['available_posts']).to eq(2)
        
        # Проверяем сводную статистику
        expect(json['summary']).to include('total_intervals', 'busy_intervals', 'free_intervals')
        expect(json['summary']['total_intervals']).to eq(36)
      end
    end
    
    context 'нерабочий день' do
      let(:sunday_date) { '2025-06-01' } # Sunday
      let(:sunday_path) { "/api/v1/service_points/#{service_point.id}/availability/#{sunday_date}/details" }
      
      it 'возвращает информацию о нерабочем дне' do
        get sunday_path, headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['is_working']).to be false
        expect(json['intervals']).to be_nil
      end
    end
  end
  
  describe 'GET /api/v1/service_points/:service_point_id/availability/week' do
    let(:path) { "/api/v1/service_points/#{service_point.id}/availability/week" }
    
    context 'обзор недели' do
      before do
        # Создаем шаблоны для всех дней недели
        (1..7).each do |day|
          weekday = create(:weekday, name: "Day#{day}", sort_order: day)
          create(:schedule_template,
            service_point: service_point,
            weekday: weekday,
            is_working_day: day <= 5, # Пн-Пт рабочие дни
            opening_time: '09:00:00',
            closing_time: '18:00:00'
          )
        end
      end
      
      it 'возвращает обзор недели' do
        get path, params: { start_date: '2025-06-02' }, headers: headers # Понедельник
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['service_point_id']).to eq(service_point.id)
        expect(json['days']).to be_an(Array)
        expect(json['days'].count).to eq(7)
        
        # Проверяем что рабочие дни помечены правильно
        monday = json['days'].find { |day| day['date'] == '2025-06-02' }
        expect(monday['is_working']).to be true
        
        saturday = json['days'].find { |day| day['date'] == '2025-06-07' }
        expect(saturday['is_working']).to be false
      end
    end
  end
  
  describe 'обработка ошибок' do
    let(:path) { "/api/v1/service_points/#{service_point.id}/availability/#{test_date}" }
    
    it 'обрабатывает некорректный формат даты' do
      invalid_path = "/api/v1/service_points/#{service_point.id}/availability/invalid-date"
      
      get invalid_path, headers: headers
      
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      
      expect(json['error']).to include('Некорректный формат даты')
    end
    
    it 'обрабатывает системные ошибки' do
      allow(DynamicAvailabilityService).to receive(:available_times_for_date)
        .and_raise(StandardError.new('Test error'))
      
      get path, headers: headers
      
      expect(response).to have_http_status(:internal_server_error)
      json = JSON.parse(response.body)
      
      expect(json['error']).to be_present
    end
  end
end 