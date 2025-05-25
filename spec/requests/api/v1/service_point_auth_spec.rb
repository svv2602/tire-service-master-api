require 'rails_helper'

RSpec.describe 'Service Point API Authentication', type: :request do
  include RequestSpecHelper
  include ServicePointsTestHelper
  
  # Create roles first
  let!(:partner_role) do
    UserRole.find_by(name: 'partner') || create(:user_role, name: 'partner', description: 'Partner role')
  end
  
  let!(:admin_role) do
    UserRole.find_by(name: 'admin') || create(:user_role, name: 'admin', description: 'Admin role')
  end
  
  # Create users with proper roles
  let!(:partner_user) { create(:user, email: 'partner_test@example.com', password: 'password123', role_id: partner_role.id) }
  let!(:partner) { create(:partner, user: partner_user) }
  
  let!(:admin_user) { create(:user, email: 'admin_test@example.com', password: 'password123', role_id: admin_role.id) }
  
  let!(:city) { create(:city) }
  let!(:active_status) { create(:service_point_status, name: 'active') }
  
  # Тестовые данные для создания сервисной точки
  let(:valid_attributes) do
    {
      service_point: {
        name: "Auth Test Point #{SecureRandom.hex(8)}",
        description: 'A new service point for auth testing',
        address: '123 Auth Test St',
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

  describe 'Protected endpoints require authentication' do
    it 'returns 401 Unauthorized when no token is provided' do
      post "/api/v1/partners/#{partner.id}/service_points", 
           params: valid_attributes.to_json,
           headers: { 'Content-Type' => 'application/json' }
      
      expect(response).to have_http_status(401)
      expect(json).to include('error')
    end
    
    it 'returns 401 Unauthorized when invalid token is provided' do
      post "/api/v1/partners/#{partner.id}/service_points", 
           params: valid_attributes.to_json,
           headers: { 
             'Authorization' => 'Bearer invalid_token',
             'Content-Type' => 'application/json'
           }
      
      expect(response).to have_http_status(401)
      expect(json).to include('error')
    end
    
    it 'allows access with valid partner token' do
      headers = generate_auth_headers(partner_user)
      
      post "/api/v1/partners/#{partner.id}/service_points", 
           params: valid_attributes.to_json,
           headers: headers
      
      expect(response).to have_http_status(201)
    end
    
    it 'allows access with valid admin token' do
      headers = generate_auth_headers(admin_user)
      
      post "/api/v1/partners/#{partner.id}/service_points", 
           params: valid_attributes.to_json,
           headers: headers
      
      expect(response).to have_http_status(201)
    end
  end
end
