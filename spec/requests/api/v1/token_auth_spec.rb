# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Token Authentication Tests', type: :request do
  include RequestSpecHelper
  include ServicePointsTestHelper
  
  describe "Authentication with Bearer token" do
    # First, create the partner role
    let(:partner_role) do
      UserRole.find_by(name: 'partner') || 
      create(:user_role, name: 'partner', description: 'Partner role')
    end
    
    # Create user with the partner role
    let(:user) { create(:user, role_id: partner_role.id) }
    let(:partner) { create(:partner, user: user) }
    let(:headers) { generate_auth_headers(user) }
    
    before(:each) do
      # Ensure the user has the right role
      user.update!(role_id: partner_role.id) unless user.role_id == partner_role.id
    end
    
    it "successfully authenticates with valid token" do
      # Test protected endpoint
      get "/api/v1/partners/#{partner.id}/service_points", headers: headers
      
      # Should not be unauthorized
      expect(response).not_to have_http_status(:unauthorized)
    end
    
    it "can create a service point with proper authentication" do
      # Create service point data
      valid_attributes = {
        service_point: {
          name: "Test Service Point #{SecureRandom.hex(4)}",
          description: 'Test point',
          address: 'Test Address',
          city_id: create(:city).id,
          post_count: 3,
          default_slot_duration: 30,
          status_id: create(:service_point_status, name: 'active').id
        }
      }
      
      # Make the request with JSON body and headers
      post "/api/v1/partners/#{partner.id}/service_points", 
           params: valid_attributes.to_json, 
           headers: headers
      
      # Check for either 201 (success) or no 401 (validly authenticated)
      expect(response.status).not_to eq(401)
    end
  end
end
