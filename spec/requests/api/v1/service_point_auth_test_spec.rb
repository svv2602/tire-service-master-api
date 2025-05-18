require 'rails_helper'

RSpec.describe 'Service Point Auth Test', type: :request do
  include RequestSpecHelper
  include ServicePointsTestHelper
  
  # Create roles first to ensure proper role assignment
  let!(:client_role) do
    UserRole.find_by(name: 'client') || create(:user_role, name: 'client', description: 'Client role')
  end
  
  let!(:partner_role) do
    UserRole.find_by(name: 'partner') || create(:user_role, name: 'partner', description: 'Partner role')
  end
  
  let!(:admin_role) do
    UserRole.find_by(name: 'administrator') || create(:user_role, name: 'administrator', description: 'Admin role')
  end
  
  # Create users with proper roles
  let(:client_user) { create(:user, role_id: client_role.id) }
  let(:partner_user) { create(:user, role_id: partner_role.id) }
  let(:partner) { create(:partner, user: partner_user) }
  let(:admin_user) { create(:user, role_id: admin_role.id) }
  
  let(:city) { create(:city) }
  let(:active_status) { create(:service_point_status, name: 'active') }
  
  # Test data for creating service point
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
  
  describe 'POST /api/v1/partners/:partner_id/service_points with valid auth' do
    it 'allows a partner to create a service point' do
      # Make sure the user has the right role
      partner_user.update!(role_id: partner_role.id)
      
      # Generate the token
      headers = generate_auth_headers(partner_user)
      
      # Make the request
      post "/api/v1/partners/#{partner.id}/service_points", 
           params: valid_attributes.to_json, 
           headers: headers
      
      # Verify the result
      expect(response).to have_http_status(201)
      expect(json['name']).to eq(valid_attributes[:service_point][:name])
    end
    
    it 'allows an admin to create a service point' do
      # Make sure admin has right role
      admin_user.update!(role_id: admin_role.id)
      
      # Generate proper headers
      headers = generate_auth_headers(admin_user)
      
      # Make the request
      post "/api/v1/partners/#{partner.id}/service_points", 
           params: valid_attributes.to_json, 
           headers: headers
      
      # Verify the result
      expect(response).to have_http_status(201)
      expect(json['name']).to eq(valid_attributes[:service_point][:name])
    end
    
    it 'rejects creation with missing data' do
      # Make sure the user has the right role
      partner_user.update!(role_id: partner_role.id)
      
      # Generate the token
      headers = generate_auth_headers(partner_user)
      
      # Make the request with invalid data
      post "/api/v1/partners/#{partner.id}/service_points", 
           params: { service_point: { name: '' } }.to_json, 
           headers: headers
      
      # Verify the result
      expect(response).to have_http_status(422)
      expect(json).to have_key('errors')
    end
    
    it 'restricts clients from creating service points' do
      # Make sure client user has client role
      client_user.update!(role_id: client_role.id)
      
      # Generate proper headers
      headers = generate_auth_headers(client_user)
      
      # Make the request
      post "/api/v1/partners/#{partner.id}/service_points", 
           params: valid_attributes.to_json, 
           headers: headers
      
      # Verify the result - API использует 401 вместо 403 для отказа в доступе
      expect(response).to have_http_status(401)
    end
  end
end
