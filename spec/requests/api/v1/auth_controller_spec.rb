# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  let!(:client_role) { UserRole.find_or_create_by!(name: 'client', description: 'Client role') }
  let!(:admin_role) { UserRole.find_or_create_by!(name: 'admin', description: 'Admin role') }
  let!(:partner_role) { UserRole.find_or_create_by!(name: 'partner', description: 'Partner role') }

  let(:password) { 'SecurePassword123!' }
  let!(:user) do
    User.create!(
      email: 'test@example.com',
      phone: '+380671234567',
      password: password,
      password_confirmation: password,
      first_name: 'Test',
      last_name: 'User',
      role: client_role,
      is_active: true,
      email_verified: true
    )
  end

  let!(:client) { Client.create!(user: user, preferred_notification_method: 'email') }

  # Common headers for JSON API requests with Authorization
  let(:json_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'POST /api/v1/auth/login' do
    let(:valid_credentials) { { auth: { login: user.email, password: password } } }
    let(:phone_credentials) { { auth: { login: user.phone, password: password } } }
    let(:wrong_password) { { auth: { login: user.email, password: 'WrongPassword!' } } }
    let(:nonexistent_user) { { auth: { login: 'nonexistent@example.com', password: password } } }

    context 'with valid email credentials' do
      it 'returns success and tokens' do
        post '/api/v1/auth/login',
             params: valid_credentials.to_json,
             headers: json_headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:access_token]).to be_present
        expect(json_response[:user]).to include(
          id: user.id,
          email: user.email,
          role: 'client'
        )
        expect(json_response[:message]).to be_present
      end

      it 'sets refresh token in cookies' do
        post '/api/v1/auth/login',
             params: valid_credentials.to_json,
             headers: json_headers

        expect(response).to have_http_status(:ok)
        expect(response.cookies['refresh_token']).to be_present
      end

      it 'updates last login timestamp' do
        expect do
          post '/api/v1/auth/login',
               params: valid_credentials.to_json,
               headers: json_headers
        end.to change { user.reload.last_login }
      end
    end

    context 'with valid phone credentials' do
      it 'returns success and tokens' do
        post '/api/v1/auth/login',
             params: phone_credentials.to_json,
             headers: json_headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:access_token]).to be_present
        expect(json_response[:user][:id]).to eq(user.id)
      end
    end

    context 'with wrong password' do
      it 'returns unauthorized error' do
        post '/api/v1/auth/login',
             params: wrong_password.to_json,
             headers: json_headers

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to be_present
      end
    end

    context 'with non-existent user' do
      it 'returns not found error' do
        post '/api/v1/auth/login',
             params: nonexistent_user.to_json,
             headers: json_headers

        expect(response).to have_http_status(:not_found)
        expect(json_response[:error]).to be_present
      end
    end

    context 'with missing credentials' do
      it 'returns unprocessable entity error' do
        post '/api/v1/auth/login',
             params: { auth: { login: '', password: '' } }.to_json,
             headers: json_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with inactive user' do
      before { user.update!(is_active: false) }

      it 'returns forbidden error' do
        post '/api/v1/auth/login',
             params: valid_credentials.to_json,
             headers: json_headers

        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to be_present
      end
    end
  end

  describe 'POST /api/v1/auth/logout' do
    context 'when authenticated' do
      it 'clears cookies and returns success' do
        # First login to get token
        post '/api/v1/auth/login',
             params: { auth: { login: user.email, password: password } }.to_json,
             headers: json_headers
        token = json_response[:access_token]

        # Then logout with Authorization header
        post '/api/v1/auth/logout',
             headers: json_headers.merge('Authorization' => "Bearer #{token}")

        expect(response).to have_http_status(:ok)
        expect(json_response[:message]).to be_present
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized error' do
        post '/api/v1/auth/logout', headers: json_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/auth/refresh' do
    context 'with valid refresh token from cookie' do
      before do
        post '/api/v1/auth/login',
             params: { auth: { login: user.email, password: password } }.to_json,
             headers: json_headers
      end

      it 'returns new access token' do
        # The refresh token is set in cookies by the login
        post '/api/v1/auth/refresh', headers: json_headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:access_token]).to be_present
        expect(json_response[:user]).to include(id: user.id)
      end
    end

    context 'without refresh token' do
      it 'returns unauthorized error' do
        post '/api/v1/auth/refresh', headers: json_headers

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to be_present
      end
    end

    context 'with inactive user' do
      before do
        post '/api/v1/auth/login',
             params: { auth: { login: user.email, password: password } }.to_json,
             headers: json_headers
        user.update!(is_active: false)
      end

      it 'returns unauthorized error' do
        post '/api/v1/auth/refresh', headers: json_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/auth/me' do
    context 'when authenticated with Authorization header' do
      it 'returns current user information' do
        get '/api/v1/auth/me',
            headers: json_headers.merge(auth_headers(user))

        expect(response).to have_http_status(:ok)
        expect(json_response[:user]).to include(
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          role: 'client'
        )
      end

      it 'includes client specific data for client role' do
        get '/api/v1/auth/me',
            headers: json_headers.merge(auth_headers(user))

        expect(response).to have_http_status(:ok)
        expect(json_response[:client]).to be_present
        expect(json_response[:client][:id]).to eq(client.id)
      end
    end

    context 'when authenticated as admin' do
      let!(:admin_user) do
        User.create!(
          email: 'admin@example.com',
          password: password,
          password_confirmation: password,
          first_name: 'Admin',
          last_name: 'User',
          role: admin_role,
          is_active: true,
          email_verified: true
        )
      end

      let!(:administrator) { Administrator.create!(user: admin_user) }

      it 'returns admin specific data' do
        get '/api/v1/auth/me',
            headers: json_headers.merge(auth_headers(admin_user))

        expect(response).to have_http_status(:ok)
        expect(json_response[:user][:role]).to eq('admin')
        expect(json_response[:admin_info]).to be_present
        expect(json_response[:admin_info][:role_permissions]).to be_an(Array)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized error' do
        get '/api/v1/auth/me', headers: json_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized error' do
        get '/api/v1/auth/me',
            headers: json_headers.merge('Authorization' => 'Bearer invalid_token')

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with expired token' do
      it 'returns unauthorized error' do
        # Generate an expired token
        expired_payload = { user_id: user.id, token_type: 'access', exp: 1.hour.ago.to_i }
        expired_token = JWT.encode(expired_payload, Auth::JsonWebToken.secret_key, 'HS256')

        get '/api/v1/auth/me',
            headers: json_headers.merge('Authorization' => "Bearer #{expired_token}")

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/auth/profile' do
    let(:update_params) { { user: { first_name: 'Updated', last_name: 'Name' } } }

    context 'when authenticated' do
      it 'updates user profile' do
        put '/api/v1/auth/profile',
            params: update_params.to_json,
            headers: json_headers.merge(auth_headers(user))

        expect(response).to have_http_status(:ok)
        expect(json_response[:user][:first_name]).to eq('Updated')
        expect(json_response[:user][:last_name]).to eq('Name')
      end

      it 'persists the changes to database' do
        put '/api/v1/auth/profile',
            params: update_params.to_json,
            headers: json_headers.merge(auth_headers(user))

        expect(response).to have_http_status(:ok)
        expect(user.reload.first_name).to eq('Updated')
        expect(user.reload.last_name).to eq('Name')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized error' do
        put '/api/v1/auth/profile',
            params: update_params.to_json,
            headers: json_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'Auth with different user roles' do
    let!(:partner_user) do
      user = User.create!(
        email: 'partner@example.com',
        password: password,
        password_confirmation: password,
        first_name: 'Partner',
        last_name: 'User',
        role: partner_role,
        is_active: true,
        email_verified: true
      )
      Partner.create!(
        user: user,
        company_name: 'Test Partner',
        contact_person: 'Contact Person',
        legal_address: 'Test Address',
        is_active: true
      )
      user
    end

    it 'allows partner to login' do
      post '/api/v1/auth/login',
           params: { auth: { login: partner_user.email, password: password } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(json_response[:user][:role]).to eq('partner')
    end

    it 'returns partner specific data for partner role' do
      get '/api/v1/auth/me',
          headers: json_headers.merge(auth_headers(partner_user))

      expect(response).to have_http_status(:ok)
      expect(json_response[:user][:role]).to eq('partner')
      expect(json_response[:partner]).to be_present
    end
  end
end
