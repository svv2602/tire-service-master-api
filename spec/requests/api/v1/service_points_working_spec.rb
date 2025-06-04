require 'rails_helper'

RSpec.describe 'API V1 ServicePoints Working Tests', type: :request do
  include RequestSpecHelper
  include ServicePointsTestHelper
  
  # Создаем роли для тестов
  let!(:partner_role) do
    UserRole.find_by(name: 'partner') || create(:user_role, name: 'partner', description: 'Partner role')
  end
  
  let!(:admin_role) do
    UserRole.find_by(name: 'admin') || create(:user_role, name: 'admin', description: 'Admin role')
  end
  
  let(:partner_user) { create(:user, role_id: partner_role.id) }
  let(:partner) { create(:partner, user: partner_user) }
  let(:partner_headers) { generate_auth_headers(partner_user) }
  
  let(:admin_user) { create(:user, role_id: admin_role.id) }
  let(:admin_headers) { generate_auth_headers(admin_user) }
  
  let(:city) { create(:city) }
  let(:service_point) { create(:service_point, partner: partner, city: city) }

  describe 'GET /api/v1/service_points' do
    it 'возвращает список сервисных точек без авторизации' do
      # Создаем несколько точек
      3.times do |i|
        create(:service_point, name: "Point #{i}", city: city)
      end
      
      get '/api/v1/service_points'
      
      expect(response).to have_http_status(200)
      expect(json['data']).to be_an(Array)
      expect(json['data'].size).to be >= 3
    end
  end
  
  describe 'GET /api/v1/service_points/:id' do
    it 'возвращает конкретную сервисную точку' do
      get "/api/v1/service_points/#{service_point.id}"
      
      expect(response).to have_http_status(200)
      expect(json['id']).to eq(service_point.id)
      expect(json['name']).to eq(service_point.name)
    end
  end
  
  describe 'GET /api/v1/partners/:partner_id/service_points' do
    it 'возвращает сервисные точки партнера с авторизацией' do
      # Создаем точки для партнера
      2.times do |i|
        create(:service_point, name: "Partner Point #{i}", partner: partner, city: city)
      end
      
      get "/api/v1/partners/#{partner.id}/service_points", headers: partner_headers
      
      expect(response).to have_http_status(200)
      expect(json['data']).to be_an(Array)
      expect(json['data'].size).to be >= 2
    end
  end
  
  describe 'PATCH /api/v1/partners/:partner_id/service_points/:id' do
    context 'обновление базовых полей' do
      let(:update_params) do
        {
          service_point: {
            name: 'Обновленное название',
            description: 'Новое описание',
            address: 'Новый адрес'
          }
        }
      end
      
      it 'обновляет основные поля сервисной точки' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: update_params.to_json,
              headers: partner_headers
        
        expect(response).to have_http_status(200)
        
        service_point.reload
        expect(service_point.name).to eq('Обновленное название')
        expect(service_point.description).to eq('Новое описание')
        expect(service_point.address).to eq('Новый адрес')
      end
    end
    
    context 'обновление с working_hours' do
      let(:schedule_params) do
        {
          service_point: {
            working_hours: {
              monday: { start: '09:00', end: '18:00', is_working_day: true },
              tuesday: { start: '09:00', end: '18:00', is_working_day: true },
              sunday: { start: '10:00', end: '16:00', is_working_day: false }
            }
          }
        }
      end
      
      it 'обновляет расписание работы' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: schedule_params.to_json,
              headers: partner_headers
        
        expect(response).to have_http_status(200)
        
        service_point.reload
        expect(service_point.working_hours['monday']['start']).to eq('09:00')
        expect(service_point.working_hours['monday']['is_working_day']).to be true
        expect(service_point.working_hours['sunday']['is_working_day']).to be false
      end
    end
  end
  
  describe 'POST /api/v1/partners/:partner_id/service_points' do
    context 'создание базовой сервисной точки' do
      let(:create_params) do
        {
          service_point: {
            name: 'Новая точка обслуживания',
            description: 'Описание новой точки',
            address: 'ул. Новая, 123',
            city_id: city.id,
            contact_phone: '+380 50 123 45 67',
            is_active: true,
            work_status: 'working'
          }
        }
      end
      
      it 'создает новую сервисную точку' do
        expect {
          post "/api/v1/partners/#{partner.id}/service_points",
               params: create_params.to_json,
               headers: partner_headers
        }.to change(ServicePoint, :count).by(1)
        
        expect(response).to have_http_status(201)
        
        created_point = ServicePoint.last
        expect(created_point.name).to eq('Новая точка обслуживания')
        expect(created_point.partner).to eq(partner)
        expect(created_point.city).to eq(city)
      end
    end
  end
  
  describe 'валидация базовых полей' do
    context 'обязательные поля' do
      let(:invalid_params) do
        {
          service_point: {
            name: '', # Пустое имя
            city_id: nil, # Отсутствует город
            address: '' # Пустой адрес
          }
        }
      end
      
      it 'возвращает ошибки валидации для обязательных полей' do
        post "/api/v1/partners/#{partner.id}/service_points",
             params: invalid_params.to_json,
             headers: partner_headers
        
        expect(response).to have_http_status(422)
        expect(json['errors']).to be_present
      end
    end
  end
  
  describe 'авторизация' do
    context 'без токена' do
      it 'возвращает ошибку для создания' do
        post "/api/v1/partners/#{partner.id}/service_points",
             params: { service_point: { name: 'Test' } }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        
        expect(response).to have_http_status(422)
      end
    end
    
    context 'с валидным токеном' do
      it 'позволяет обновление своих точек' do
        patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
              params: { service_point: { name: 'Обновлено' } }.to_json,
              headers: partner_headers
        
        expect(response).to have_http_status(200)
      end
    end
  end
  
  describe 'GET /api/v1/service_points/:id/basic' do
    it 'возвращает базовую информацию о сервисной точке' do
      get "/api/v1/service_points/#{service_point.id}/basic"
      
      expect(response).to have_http_status(200)
      expect(json['id']).to eq(service_point.id)
      expect(json['name']).to eq(service_point.name)
      expect(json['address']).to eq(service_point.address)
      expect(json['city']).to be_present
      expect(json['partner']).to be_present
    end
  end
end 