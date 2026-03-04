# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Devices API', type: :request do
  let(:user) { create(:client_user) }
  let(:headers) { valid_headers(user) }

  describe 'GET /api/v1/devices' do
    let!(:device1) { create(:device, user: user, platform: 'ios') }
    let!(:device2) { create(:device, :android, user: user) }
    let!(:inactive) { create(:device, :inactive, user: user) }

    it 'returns active devices for the current user' do
      get '/api/v1/devices', headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['devices'].length).to eq(2)
      expect(body['active_count']).to eq(2)
      expect(body['total_count']).to eq(3)
    end
  end

  describe 'GET /api/v1/devices/:id' do
    let!(:device) { create(:device, user: user) }

    it 'returns device details' do
      get "/api/v1/devices/#{device.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['id']).to eq(device.id)
      expect(body['platform']).to eq('ios')
    end

    it 'returns 404 for device of another user' do
      other_user = create(:client_user)
      other_device = create(:device, user: other_user)

      get "/api/v1/devices/#{other_device.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/devices' do
    let(:valid_params) do
      {
        device: {
          device_token: 'new_unique_token_abc123',
          platform: 'ios',
          device_name: 'iPhone 15',
          device_model: 'iPhone15,2',
          os_version: '17.4',
          app_version: '1.0.0'
        }
      }
    end

    it 'creates a new device' do
      expect {
        post '/api/v1/devices', params: valid_params.to_json, headers: headers
      }.to change(Device, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['device']['platform']).to eq('ios')
      expect(body['message']).to eq('Device registered')
    end

    it 'updates existing device with same token' do
      create(:device, user: user, device_token: 'new_unique_token_abc123', app_version: '0.9.0')

      expect {
        post '/api/v1/devices', params: valid_params.to_json, headers: headers
      }.not_to change(Device, :count)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['message']).to eq('Device token updated')
    end

    it 'reassigns device from another user' do
      other_user = create(:client_user)
      existing = create(:device, user: other_user, device_token: 'new_unique_token_abc123')

      post '/api/v1/devices', params: valid_params.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      existing.reload
      expect(existing.user_id).to eq(user.id)
    end

    it 'returns validation errors for invalid params' do
      invalid_params = { device: { device_token: '', platform: 'windows' } }

      post '/api/v1/devices', params: invalid_params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/devices/:id' do
    let!(:device) { create(:device, user: user, app_version: '1.0.0') }

    it 'updates device info' do
      patch "/api/v1/devices/#{device.id}",
            params: { device: { app_version: '1.1.0' } }.to_json,
            headers: headers

      expect(response).to have_http_status(:ok)
      device.reload
      expect(device.app_version).to eq('1.1.0')
    end
  end

  describe 'DELETE /api/v1/devices/:id' do
    let!(:device) { create(:device, user: user) }

    it 'deactivates the device' do
      delete "/api/v1/devices/#{device.id}", headers: headers

      expect(response).to have_http_status(:ok)
      device.reload
      expect(device.is_active).to be false
    end
  end

  describe 'API-Version header' do
    it 'returns API-Version header in response' do
      get '/api/v1/devices', headers: headers

      expect(response.headers['API-Version']).to eq('1')
    end

    it 'echoes back the requested API-Version' do
      get '/api/v1/devices', headers: headers.merge('API-Version' => '1')

      expect(response.headers['API-Version']).to eq('1')
    end
  end
end
