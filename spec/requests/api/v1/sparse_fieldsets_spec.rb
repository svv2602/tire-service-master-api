# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sparse Fieldsets', type: :request do
  let(:user) { create(:client_user) }
  let(:headers) { valid_headers(user) }

  describe 'GET /api/v1/devices?fields=id,platform' do
    let!(:device) { create(:device, user: user) }

    it 'returns only requested fields plus id' do
      get '/api/v1/devices?fields=platform,device_name', headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      devices = body['devices']
      expect(devices.first.keys).to contain_exactly('id', 'platform', 'device_name')
    end

    it 'returns all fields when no fields param is given' do
      get '/api/v1/devices', headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      devices = body['devices']
      expect(devices.first.keys.length).to be > 3
    end
  end
end
