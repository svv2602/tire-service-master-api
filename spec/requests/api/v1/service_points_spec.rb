require 'rails_helper'

RSpec.describe 'API V1 ServicePoints', type: :request do
  include RequestSpecHelper
  include ServicePointsTestHelper
  
  let(:client_user) { create(:client_user) }
  let(:client_headers) { generate_auth_headers(client_user) }
  let(:partner_user) { create(:partner_user) }
  let(:partner) { partner_user.partner }
  let(:partner_headers) { generate_auth_headers(partner_user) }
  
  let(:admin_user) { create(:admin) }
  let(:admin_headers) { generate_auth_headers(admin_user) }
  
  let(:city) { create(:city) }
  let(:amenity1) { create(:amenity) }
  let(:amenity2) { create(:amenity) }
  
  # Вместо массового создания 5 сервисных точек, будем создавать их по одной в каждом тесте или группе тестов
  let(:service_point) { create(:service_point, city: city, partner: partner) }
  let(:service_point_id) { service_point.id }
  let(:active_status) { create(:service_point_status, name: 'active') }
  let(:closed_status) { create(:service_point_status, name: 'closed') }
  
  describe 'GET /api/v1/service_points' do
    context 'public access' do
      before do
        # Очищаем таблицу перед тестом
        clear_service_points
        
        # Создаем несколько сервисных точек с гарантированно уникальными именами
        3.times do |i|
          create_unique_service_point(
            name: unique_name("TestPoint-#{i}"), 
            city: city, 
            partner: partner
          )
        end
        get '/api/v1/service_points'
      end
      
      it 'returns service points' do
        expect(json).not_to be_empty
        expect(json['data'].size).to eq(3)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end
    
    context 'with filters' do
      it 'filters by city_id' do
        clear_service_points
        
        sp = create_unique_service_point(name: unique_name("CityFilter"), city: city, partner: partner)
        another_city = create(:city)
        other_city_point = create_unique_service_point(name: unique_name("OtherCity"), city: another_city)
        
        get '/api/v1/service_points', params: { city_id: city.id }
        
        expect(json['data'].size).to eq(1)
        expect(json['data'].first['id']).to eq(sp.id)
      end
      
      it 'filters by amenities' do
        clear_service_points
        
        # Создаем сервисную точку с двумя удобствами
        point = create_unique_service_point(name: unique_name("AmenityPoint"), city: city, partner: partner)
        create(:service_point_amenity, service_point: point, amenity: amenity1)
        create(:service_point_amenity, service_point: point, amenity: amenity2)
        
        # Создаем сервисную точку только с одним удобством
        point2 = create_unique_service_point(name: unique_name("SingleAmenity"), city: city, partner: partner)
        create(:service_point_amenity, service_point: point2, amenity: amenity1)
        
        # Проверяем, что фильтр по обоим удобствам вернет только точку с обоими удобствами
        get '/api/v1/service_points', params: { amenity_ids: [amenity1.id, amenity2.id].join(',') }
        
        expect(json['data'].size).to eq(1)
        expect(json['data'].first['id']).to eq(point.id)
      end
      
      it 'filters by query' do
        clear_service_points
        
        unique_name_value = "UniqueQueryTestPoint-#{Time.now.to_i}"
        unique_point = create_unique_service_point(name: unique_name_value)
        
        get '/api/v1/service_points', params: { query: unique_name_value }
        
        expect(json['data'].size).to eq(1)
        expect(json['data'].first['name']).to eq(unique_name_value)
      end
      
      it 'sorts by rating' do
        clear_service_points
        
        high_rated = create_unique_service_point(name: unique_name("HighRated"), average_rating: 5.0)
        low_rated = create_unique_service_point(name: unique_name("LowRated"), average_rating: 1.0)
        
        get '/api/v1/service_points', params: { sort_by: 'rating' }
        
        expect(json['data'].first['id']).to eq(high_rated.id)
        expect(json['data'].last['id']).to eq(low_rated.id)
      end
    end
    
    context 'by partner' do
      it 'returns only service points for the specified partner' do
        clear_service_points
        
        point1 = create_unique_service_point(name: unique_name("PartnerPoint"), partner: partner)
        another_partner = create(:partner)
        point2 = create_unique_service_point(name: unique_name("OtherPartnerPoint"), partner: another_partner)
        
        get "/api/v1/partners/#{partner.id}/service_points", headers: partner_headers
        
        expect(json['data'].size).to eq(1)
        expect(json['data'].map { |p| p['id'] }).to include(point1.id)
        expect(json['data'].map { |p| p['id'] }).not_to include(point2.id)
      end
    end
  end

  describe 'GET /api/v1/service_points/:id' do
    let(:test_point) { create(:service_point, name: "Test Point For ID #{SecureRandom.hex(8)}") }
    
    context 'public access' do
      before { get "/api/v1/service_points/#{test_point.id}" }
      
      it 'returns the service point' do
        expect(json).not_to be_empty
        expect(json['id']).to eq(test_point.id)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'when service point does not exist' do
      before { get "/api/v1/service_points/999" }
      
      it 'returns status code 404' do
        expect(response).to have_http_status(404)
      end
      
      it 'returns a not found message' do
        expect(response.body).to match(/Resource not found/)
      end
    end
  end

  describe 'GET /api/v1/service_points/:id/basic' do
    let(:test_point) { create(:service_point, name: "Test Point For Basic #{SecureRandom.hex(8)}", city: city, partner: partner) }
    
    context 'public access' do
      before { get "/api/v1/service_points/#{test_point.id}/basic" }
      
      it 'returns basic information about the service point' do
        expect(json).not_to be_empty
        expect(json['id']).to eq(test_point.id)
        expect(json['name']).to eq(test_point.name)
        expect(json['address']).to eq(test_point.address)
        expect(json['contact_phone']).to eq(test_point.contact_phone)
        expect(json['status_id']).to eq(test_point.status_id)
        
        # Проверяем данные города
        expect(json['city']['id']).to eq(test_point.city.id)
        expect(json['city']['name']).to eq(test_point.city.name)
        expect(json['city']['region']['id']).to eq(test_point.city.region.id)
        expect(json['city']['region']['name']).to eq(test_point.city.region.name)
        
        # Проверяем данные партнера
        expect(json['partner']['id']).to eq(test_point.partner.id)
        expect(json['partner']['company_name']).to eq(test_point.partner.company_name)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
      
      it 'does not return full service point details' do
        expect(json).not_to include('description')
        expect(json).not_to include('latitude')
        expect(json).not_to include('longitude')
        expect(json).not_to include('post_count')
        expect(json).not_to include('default_slot_duration')
      end
    end

    context 'when service point does not exist' do
      before { get "/api/v1/service_points/999/basic" }
      
      it 'returns status code 404' do
        expect(response).to have_http_status(404)
      end
      
      it 'returns a not found message' do
        expect(response.body).to match(/Resource not found/)
      end
    end
  end

  describe 'POST /api/v1/partners/:partner_id/service_points' do
    let(:valid_attributes) do
      {
        service_point: {
          name: "New Service Point #{SecureRandom.hex(8)}",
          description: 'A new service point',
          address: '123 Test St',
          city_id: city.id,
          latitude: 55.7558,
          longitude: 37.6173,
          contact_phone: '+79001234567',
          post_count: 3,
          default_slot_duration: 30,
          status_id: active_status.id
        }
      }
    end
    
    context 'when request is valid' do
      context 'as a partner' do
        before do
          # Create a specific test user for this context
          @test_user = partner_user
          
          # Create proper authentication headers
          # Create role if it doesn't exist
          partner_role = UserRole.find_by(name: 'partner') || create(:user_role, name: 'partner', description: 'Partner role')
          
          # Make sure the user has the right role
          partner_user.update!(role_id: partner_role.id) unless partner_user.role_id == partner_role.id
          
          # Generate the token
          @headers = generate_auth_headers(partner_user)
          
          # Make the request with proper JSON formatting and headers
          post "/api/v1/partners/#{partner.id}/service_points", 
               params: valid_attributes.to_json, 
               headers: @headers
          
          # Debug response
          check_auth_response(response)
        end
        
        it 'creates a service point' do
          expect(response).to have_http_status(201)
          expect(json['name']).to eq(valid_attributes[:service_point][:name])
        end
        
        it 'returns status code 201' do
          expect(response).to have_http_status(201)
        end
      end
      
      context 'as an admin' do
        before do
          # Создаем роль администратора, если она еще не существует
          admin_role = UserRole.find_by(name: 'admin') ||
            create(:user_role, name: 'admin', description: 'Admin role')
          
          # Make sure admin has right role
          admin_user.update!(role_id: admin_role.id) unless admin_user.role_id == admin_role.id
          
          # Generate proper headers
          headers = generate_auth_headers(admin_user)
          
          post "/api/v1/partners/#{partner.id}/service_points", 
               params: valid_attributes.to_json, 
               headers: headers
          
          # Debug any issues
          check_auth_response(response)
        end
        
        it 'creates a service point' do
          expect(json['name']).to eq(valid_attributes[:service_point][:name])
        end
        
        it 'returns status code 201' do
          expect(response).to have_http_status(201)
        end
      end
    end
    
    context 'when request is invalid' do
      before do
        # Ensure we have a valid partner role
        partner_role = UserRole.find_by(name: 'partner') || 
                      create(:user_role, name: 'partner', description: 'Partner role')
        
        # Update partner user role if needed
        partner_user.update!(role_id: partner_role.id) unless partner_user.role_id == partner_role.id
        
        # Generate proper headers
        headers = generate_auth_headers(partner_user)
        
        post "/api/v1/partners/#{partner.id}/service_points", 
             params: { service_point: { name: '' } }.to_json,
             headers: headers
      end
      
      it 'returns status code 422' do
        expect(response).to have_http_status(422)
      end
      
      it 'returns a validation failure message' do
        expect(json['errors']).to be_present
      end
    end
    
    context 'with invalid permissions' do
      before do
        # Ensure client user has client role
        client_role = UserRole.find_by(name: 'client') || create(:user_role, name: 'client', description: 'Client role')
        client_user.update!(role_id: client_role.id) unless client_user.role_id == client_role.id
        
        # Generate proper headers
        headers = generate_auth_headers(client_user)
        
        post "/api/v1/partners/#{partner.id}/service_points", 
             params: valid_attributes.to_json, 
             headers: headers
        
        # Debug issues
        check_auth_response(response)
      end
      
      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'PATCH /api/v1/partners/:partner_id/service_points/:id' do
    let(:update_point) { create(:service_point, name: "Point To Update #{SecureRandom.hex(8)}", partner: partner) }
    let(:valid_attributes) do
      { service_point: { name: "Updated Service Point #{SecureRandom.hex(8)}" } }
    end
    
    context 'as a partner' do
      before do
        patch "/api/v1/partners/#{partner.id}/service_points/#{update_point.id}", 
              params: valid_attributes.to_json, 
              headers: partner_headers.merge('Content-Type' => 'application/json')
      end
      
      it 'updates the service point' do
        expect(json['name']).to eq(valid_attributes[:service_point][:name])
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end
    
    context 'as an admin' do
      before do
        patch "/api/v1/partners/#{partner.id}/service_points/#{update_point.id}", 
              params: valid_attributes.to_json, 
              headers: admin_headers.merge('Content-Type' => 'application/json')
      end
      
      it 'updates the service point' do
        expect(json['name']).to eq(valid_attributes[:service_point][:name])
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end
    
    context 'with invalid permissions' do
      before do
        patch "/api/v1/partners/#{partner.id}/service_points/#{update_point.id}", 
              params: valid_attributes.to_json, 
              headers: client_headers.merge('Content-Type' => 'application/json')
      end
      
      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'DELETE /api/v1/partners/:partner_id/service_points/:id' do
    let(:delete_point) { create(:service_point, name: "Point To Delete #{SecureRandom.hex(8)}", partner: partner, status: active_status) }
    
    before do
      allow(ServicePointStatus).to receive(:find_by).with(name: 'closed').and_return(closed_status)
    end
    
    context 'as a partner' do
      before do
        delete "/api/v1/partners/#{partner.id}/service_points/#{delete_point.id}", 
               headers: partner_headers.merge('Content-Type' => 'application/json')
      end
      
      it 'returns success message' do
        expect(json['message']).to match(/Service point closed successfully/)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
      
      it 'changes the status to closed' do
        expect(ServicePoint.find(delete_point.id).status_id).to eq(closed_status.id)
      end
    end
    
    context 'as an admin' do
      before do
        delete "/api/v1/partners/#{partner.id}/service_points/#{delete_point.id}", 
               headers: admin_headers.merge('Content-Type' => 'application/json')
      end
      
      it 'returns success message' do
        expect(json['message']).to match(/Service point closed successfully/)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end
    
    context 'with invalid permissions' do
      before do
        delete "/api/v1/partners/#{partner.id}/service_points/#{delete_point.id}", 
               headers: client_headers.merge('Content-Type' => 'application/json')
      end
      
      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /api/v1/service_points/nearby' do
    before { clear_service_points }
    
    let!(:nearby_point) { create_unique_service_point(latitude: 55.7558, longitude: 37.6173, name: unique_name("NearbyPoint")) }
    let!(:distant_point) { create_unique_service_point(latitude: 59.9343, longitude: 30.3351, name: unique_name("DistantPoint")) }
    
    before do
      get '/api/v1/service_points/nearby', 
          params: { latitude: 55.7558, longitude: 37.6173, distance: 10 },
          headers: client_headers
    end
    
    it 'returns nearby service points' do
      expect(json['data']).to be_an(Array)
      expect(json['data'].map { |p| p['id'] }).to include(nearby_point.id)
      expect(json['data'].map { |p| p['id'] }).not_to include(distant_point.id)
    end
    
    it 'returns status code 200' do
      expect(response).to have_http_status(200)
    end
  end
end
