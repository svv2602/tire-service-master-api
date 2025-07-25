require 'rails_helper'

RSpec.describe 'Тесты безопасности изоляции данных', type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:partner1) { create(:partner) }
  let!(:partner2) { create(:partner) }
  let!(:partner1_user) { create(:user, :partner, partner: partner1) }
  let!(:partner2_user) { create(:user, :partner, partner: partner2) }
  let!(:operator1) { create(:operator, partner: partner1) }
  let!(:operator2) { create(:operator, partner: partner2) }
  let!(:operator1_user) { create(:user, :operator, operator: operator1) }
  let!(:operator2_user) { create(:user, :operator, operator: operator2) }
  
  let!(:service_point1) { create(:service_point, partner: partner1) }
  let!(:service_point2) { create(:service_point, partner: partner2) }
  let!(:client1) { create(:client, partner: partner1) }
  let!(:client2) { create(:client, partner: partner2) }
  let!(:booking1) { create(:booking, service_point: service_point1, client: client1) }
  let!(:booking2) { create(:booking, service_point: service_point2, client: client2) }

  describe 'Penetration Testing: Попытки обхода изоляции данных' do
    context 'Партнер пытается получить доступ к чужим данным' do
      before { sign_in partner1_user }

      it 'не может получить список клиентов другого партнера' do
        get '/api/v1/clients', headers: auth_headers
        
        expect(response).to have_http_status(:success)
        clients = JSON.parse(response.body)['data']
        
        # Должен видеть только своих клиентов
        expect(clients.map { |c| c['id'] }).to include(client1.id)
        expect(clients.map { |c| c['id'] }).not_to include(client2.id)
      end

      it 'не может получить доступ к чужой сервисной точке' do
        get "/api/v1/service_points/#{service_point2.id}", headers: auth_headers
        
        expect(response).to have_http_status(:forbidden)
      end

      it 'не может получить список бронирований другого партнера' do
        get '/api/v1/bookings', headers: auth_headers
        
        expect(response).to have_http_status(:success)
        bookings = JSON.parse(response.body)['data']
        
        # Должен видеть только бронирования своих точек
        expect(bookings.map { |b| b['id'] }).to include(booking1.id)
        expect(bookings.map { |b| b['id'] }).not_to include(booking2.id)
      end

      it 'не может создать оператора для другого партнера' do
        post '/api/v1/operators', 
             params: { 
               operator: { 
                 partner_id: partner2.id,
                 position: 'Test Operator',
                 access_level: 1,
                 user_attributes: {
                   email: 'test@example.com',
                   first_name: 'Test',
                   last_name: 'User',
                   phone: '+380123456789'
                 }
               }
             }, 
             headers: auth_headers
        
        expect(response).to have_http_status(:forbidden)
      end

      it 'не может обновить данные чужого клиента' do
        patch "/api/v1/clients/#{client2.id}",
              params: { client: { first_name: 'Hacked' } },
              headers: auth_headers
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'Оператор пытается получить доступ к данным вне своих точек' do
      before do
        # Назначаем оператора только на service_point1
        create(:operator_service_point, operator: operator1, service_point: service_point1)
        sign_in operator1_user
      end

      it 'не может получить доступ к сервисной точке другого партнера' do
        get "/api/v1/service_points/#{service_point2.id}", headers: auth_headers
        
        expect(response).to have_http_status(:forbidden)
      end

      it 'не может видеть бронирования других точек' do
        get '/api/v1/bookings', headers: auth_headers
        
        expect(response).to have_http_status(:success)
        bookings = JSON.parse(response.body)['data']
        
        # Должен видеть только бронирования назначенной точки
        booking_service_point_ids = bookings.map { |b| b['service_point_id'] }.uniq
        expect(booking_service_point_ids).to eq([service_point1.id])
      end

      it 'не может управлять операторами' do
        post '/api/v1/operators',
             params: { 
               operator: { 
                 partner_id: partner1.id,
                 position: 'Test Operator',
                 access_level: 1
               }
             },
             headers: auth_headers
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'SQL Injection и Parameter Tampering' do
      before { sign_in partner1_user }

      it 'защищен от SQL injection в параметрах поиска' do
        malicious_query = "'; DROP TABLE users; --"
        
        get '/api/v1/clients', 
            params: { query: malicious_query },
            headers: auth_headers
        
        expect(response).to have_http_status(:success)
        # Таблица users должна существовать
        expect { User.count }.not_to raise_error
      end

      it 'защищен от parameter tampering в фильтрах' do
        # Попытка подделать partner_id в параметрах
        get '/api/v1/service_points',
            params: { partner_id: partner2.id },
            headers: auth_headers
        
        expect(response).to have_http_status(:success)
        service_points = JSON.parse(response.body)['data']
        
        # Не должен видеть точки другого партнера
        expect(service_points).to be_empty
      end

      it 'защищен от массового назначения (mass assignment)' do
        patch "/api/v1/clients/#{client1.id}",
              params: { 
                client: { 
                  first_name: 'Updated',
                  partner_id: partner2.id  # Попытка сменить партнера
                }
              },
              headers: auth_headers
        
        client1.reload
        expect(client1.partner_id).to eq(partner1.id)  # Партнер не должен измениться
        expect(client1.first_name).to eq('Updated')    # Разрешенное поле должно обновиться
      end
    end

    context 'Проверка авторизации на уровне контроллеров' do
      it 'требует аутентификацию для защищенных эндпоинтов' do
        get '/api/v1/users'
        
        expect(response).to have_http_status(:unauthorized)
      end

      it 'проверяет права доступа для каждого действия' do
        sign_in operator1_user
        
        # Оператор не может управлять пользователями
        get '/api/v1/users', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
        
        post '/api/v1/users', 
             params: { user: { email: 'test@example.com' } },
             headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'Граничные случаи и исключения' do
      before { sign_in partner1_user }

      it 'обрабатывает несуществующие ID корректно' do
        get "/api/v1/service_points/99999", headers: auth_headers
        
        expect(response).to have_http_status(:not_found)
      end

      it 'обрабатывает невалидные параметры' do
        get '/api/v1/bookings',
            params: { page: -1, per_page: 'invalid' },
            headers: auth_headers
        
        expect(response).to have_http_status(:success)
        # Должны применяться значения по умолчанию
      end

      it 'защищен от переполнения параметров пагинации' do
        get '/api/v1/clients',
            params: { per_page: 10000 },
            headers: auth_headers
        
        expect(response).to have_http_status(:success)
        clients = JSON.parse(response.body)['data']
        # Не должно возвращать больше максимального лимита
        expect(clients.length).to be <= 100
      end
    end
  end

  describe 'Тестирование производительности под нагрузкой' do
    before { sign_in admin }

    it 'выдерживает множественные запросы к списку сервисных точек' do
      start_time = Time.current
      
      10.times do
        get '/api/v1/service_points', headers: auth_headers
        expect(response).to have_http_status(:success)
      end
      
      execution_time = Time.current - start_time
      expect(execution_time).to be < 5.seconds  # Должно выполняться быстро благодаря кэшированию
    end

    it 'эффективно обрабатывает фильтрацию по ролям' do
      # Создаем больше тестовых данных
      create_list(:user, 50, :client)
      create_list(:user, 20, :partner)
      
      start_time = Time.current
      
      get '/api/v1/users', 
          params: { role: 'client', per_page: 50 },
          headers: auth_headers
      
      execution_time = Time.current - start_time
      expect(response).to have_http_status(:success)
      expect(execution_time).to be < 2.seconds
    end
  end

  private

  def auth_headers
    token = JWT.encode({ user_id: @current_user.id }, Rails.application.secret_key_base)
    { 'Authorization' => "Bearer #{token}" }
  end

  def sign_in(user)
    @current_user = user
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end
end 