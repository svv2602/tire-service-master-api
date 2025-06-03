require 'rails_helper'

RSpec.describe 'Service Points Work Statuses API', type: :request do
  describe 'GET /api/v1/service_points/work_statuses' do
    context 'без авторизации' do
      it 'возвращает список статусов работы' do
        get '/api/v1/service_points/work_statuses'
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to be_an(Array)
        expect(json_response.size).to eq(4)
        
        # Проверяем структуру каждого статуса
        expected_statuses = %w[working temporarily_closed maintenance suspended]
        expect(json_response.map { |status| status['value'] }).to match_array(expected_statuses)
        
        # Проверяем наличие обязательных полей
        json_response.each do |status|
          expect(status).to have_key('value')
          expect(status).to have_key('label')
          expect(status).to have_key('description')
          expect(status['value']).to be_present
          expect(status['label']).to be_present
          expect(status['description']).to be_present
        end
      end

      it 'возвращает статус "working" с правильными данными' do
        get '/api/v1/service_points/work_statuses'
        
        json_response = JSON.parse(response.body)
        working_status = json_response.find { |status| status['value'] == 'working' }
        
        expect(working_status).to be_present
        expect(working_status['label']).to eq('Работает')
        expect(working_status['description']).to eq('Точка работает в обычном режиме')
      end

      it 'возвращает статус "temporarily_closed" с правильными данными' do
        get '/api/v1/service_points/work_statuses'
        
        json_response = JSON.parse(response.body)
        temp_closed_status = json_response.find { |status| status['value'] == 'temporarily_closed' }
        
        expect(temp_closed_status).to be_present
        expect(temp_closed_status['label']).to eq('Временно закрыта')
        expect(temp_closed_status['description']).to eq('Точка временно не работает')
      end

      it 'возвращает статус "maintenance" с правильными данными' do
        get '/api/v1/service_points/work_statuses'
        
        json_response = JSON.parse(response.body)
        maintenance_status = json_response.find { |status| status['value'] == 'maintenance' }
        
        expect(maintenance_status).to be_present
        expect(maintenance_status['label']).to eq('Техобслуживание')
        expect(maintenance_status['description']).to eq('Проводится техническое обслуживание')
      end

      it 'возвращает статус "suspended" с правильными данными' do
        get '/api/v1/service_points/work_statuses'
        
        json_response = JSON.parse(response.body)
        suspended_status = json_response.find { |status| status['value'] == 'suspended' }
        
        expect(suspended_status).to be_present
        expect(suspended_status['label']).to eq('Приостановлена')
        expect(suspended_status['description']).to eq('Работа точки приостановлена')
      end
    end

    context 'с авторизацией' do
      let(:user) { create(:user, :admin) }
      let(:headers) { auth_headers_for(user) }

      it 'также возвращает список статусов работы' do
        get '/api/v1/service_points/work_statuses', headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to be_an(Array)
        expect(JSON.parse(response.body).size).to eq(4)
      end
    end
  end

  private

  def auth_headers_for(user)
    token = JWT.encode(
      { user_id: user.id, exp: 1.hour.from_now.to_i, token_type: 'access' },
      Rails.application.credentials.secret_key_base
    )
    { 'Authorization' => "Bearer #{token}" }
  end
end 