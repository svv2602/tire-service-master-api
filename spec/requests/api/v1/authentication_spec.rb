require 'rails_helper'

RSpec.describe 'API V1 Authentication', type: :request do
  describe 'POST /api/v1/auth/login' do
    let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }
    let(:valid_credentials) do
      { 
        email: 'test@example.com',
        password: 'password123'
      }
    end
    let(:invalid_credentials) do
      {
        email: 'test@example.com',
        password: 'wrong_password'
      }
    end

    context 'When request is valid' do
      before { post '/api/v1/auth/login', params: valid_credentials }

      it 'returns an authentication token' do
        expect(json['tokens']['access']).not_to be_nil
      end

      it 'returns user information' do
        expect(json['user']).not_to be_nil
        expect(json['user']['email']).to eq('test@example.com')
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'When request is invalid' do
      before { post '/api/v1/auth/login', params: invalid_credentials }

      it 'returns a failure message' do
        expect(json['error']).to match(/Неверные учетные данные/)
      end

      it 'returns status code 401' do
        expect(response).to have_http_status(401)
      end
    end
  end
  
  describe 'POST /api/v1/clients/register' do
    let!(:client_role) do
      UserRole.find_by(name: 'client') || 
      create(:user_role, name: 'client', description: 'Client role for users who book services')
    end
    
    let(:valid_attributes) do
      {
        user: {
          email: 'new@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          first_name: 'John',
          last_name: 'Doe'
        }
      }
    end

    context 'when valid request' do
      before { post '/api/v1/clients/register', params: valid_attributes }

      it 'creates a new user' do
        expect(response).to have_http_status(201)
      end

      it 'returns success message' do
        expect(json['message']).to match(/Регистрация прошла успешно/)
      end

      it 'returns an authentication token' do
        expect(json['tokens']['access']).not_to be_nil
      end
    end

    context 'when request with missing fields' do
      let(:invalid_attributes) do
        { user: { email: 'invalid', password: 'short' } }
      end
      
      before { post '/api/v1/clients/register', params: invalid_attributes }

      it 'returns status code 422' do
        expect(response).to have_http_status(422)
      end

      it 'returns validation error message' do
        expect(json['error']).to be_present
      end
    end
  end
  
  describe 'Token Authentication' do
    include RequestSpecHelper
    include ServicePointsTestHelper
    
    let!(:admin_role) do
      UserRole.find_by(name: 'admin') ||
      create(:user_role, name: 'admin', description: 'Administrator role with full access')
    end
    
    let!(:user) { create(:user, email: 'auth_test@example.com', password: 'password123', role: admin_role) }
    let(:token) { Auth::JsonWebToken.encode_access_token(user_id: user.id) }
    let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }
    
    it 'allows access to protected routes with valid token' do
      get '/api/v1/service_points', headers: headers
      expect(response).to have_http_status(200)
    end
    
    it 'allows access to public routes without token' do
      get '/api/v1/service_points', params: { protected: true }
      expect(response).to have_http_status(200)
    end
    
    it 'allows access to public routes with invalid token' do
      get '/api/v1/service_points', 
          headers: { 'Authorization' => 'Bearer invalid_token' }, 
          params: { protected: true }
      expect(response).to have_http_status(200)
    end
  end
end
