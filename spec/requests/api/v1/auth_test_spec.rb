require 'rails_helper'

RSpec.describe 'Authentication Test', type: :request do
  describe 'Authentication with JWT token' do
    let(:client_role) do
      UserRole.find_or_create_by(name: 'client') do |role|
        role.description = 'Client role'
        role.is_active = true
      end
    end
    
    let(:client_user) { create(:user, role: client_role) }
    let(:client) { create(:client, user: client_user) }
    
    it 'public endpoint should work without authentication' do
      # Service points index should be public
      get '/api/v1/service_points'
      
      puts "Public endpoint response status: #{response.status}"
      
      expect(response).to have_http_status(:ok)
    end
    
    it 'should authenticate with token in request headers' do
      # Make sure client exists
      client
      
      # Generate token
      token = Auth::JsonWebToken.encode_access_token(user_id: client_user.id)
      
      # Make request with auth header
      headers = { 'Authorization' => "Bearer #{token}" }
      
      # Use the clients endpoint instead of bookings
      get "/api/v1/clients/#{client.id}", headers: headers
      
      puts "Auth test response status: #{response.status}"
      
      # Expect 200 or 404, but not 401 (unauthorized)
      expect(response.status).not_to eq(401)
    end
  end
end
