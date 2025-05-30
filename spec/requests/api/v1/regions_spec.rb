require 'rails_helper'

RSpec.describe 'API V1 Regions', type: :request do
  include RequestSpecHelper

  let(:admin_user) { create(:admin) }
  let(:admin_headers) { generate_auth_headers(admin_user) }

  describe 'GET /api/v1/regions' do
    let!(:active_region) { create(:region, name: 'Kyiv Region', is_active: true) }
    let!(:inactive_region) { create(:region, name: 'Lviv Region', is_active: false) }
    let!(:city) { create(:city, region: active_region, name: 'Test City') }

    context 'public access' do
      it 'returns all regions with cities count' do
        get '/api/v1/regions'
        
        expect(response).to have_http_status(200)
        expect(json).to have_key('data')
        expect(json).to have_key('pagination')
        
        region_data = json['data'].find { |r| r['id'] == active_region.id }
        expect(region_data).to include(
          'id' => active_region.id,
          'name' => 'Kyiv Region',
          'is_active' => true,
          'cities_count' => 1
        )
      end

      it 'supports search by name' do
        get '/api/v1/regions', params: { search: 'Kyiv' }
        
        expect(response).to have_http_status(200)
        region_names = json['data'].map { |r| r['name'] }
        expect(region_names).to include('Kyiv Region')
        expect(region_names).not_to include('Lviv Region')
      end

      it 'supports filtering by active status' do
        get '/api/v1/regions', params: { is_active: true }
        
        expect(response).to have_http_status(200)
        active_statuses = json['data'].map { |r| r['is_active'] }
        expect(active_statuses).to all(be true)
      end

      it 'supports pagination' do
        create_list(:region, 15, is_active: true)
        
        get '/api/v1/regions', params: { page: 1, per_page: 10 }
        
        expect(response).to have_http_status(200)
        expect(json['data'].length).to eq(10)
        expect(json['pagination']).to include(
          'current_page' => 1,
          'per_page' => 10
        )
      end
    end
  end

  describe 'GET /api/v1/regions/:id' do
    let!(:region) { create(:region, name: 'Test Region') }
    let!(:cities) { create_list(:city, 3, region: region) }

    context 'public access' do
      it 'returns region with cities' do
        get "/api/v1/regions/#{region.id}"
        
        expect(response).to have_http_status(200)
        expect(json).to include(
          'id' => region.id,
          'name' => 'Test Region',
          'cities_count' => 3
        )
        expect(json['cities']).to be_an(Array)
        expect(json['cities'].length).to eq(3)
      end
    end

    context 'when region does not exist' do
      it 'returns 404' do
        get '/api/v1/regions/999'
        
        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'POST /api/v1/regions' do
    let(:valid_attributes) do
      {
        region: {
          name: 'New Region',
          code: 'NR',
          is_active: true
        }
      }
    end

    context 'when admin authenticated' do
      it 'creates a new region' do
        expect {
          post '/api/v1/regions',
               params: valid_attributes.to_json,
               headers: admin_headers.merge('Content-Type' => 'application/json')
        }.to change(Region, :count).by(1)

        expect(response).to have_http_status(201)
        expect(json).to include(
          'name' => 'New Region',
          'code' => 'NR',
          'is_active' => true,
          'cities_count' => 0
        )
      end

      it 'returns validation errors for invalid data' do
        post '/api/v1/regions',
             params: { region: { name: '' } }.to_json,
             headers: admin_headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(422)
        expect(json).to have_key('errors')
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v1/regions',
             params: valid_attributes.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(401)
      end
    end
  end

  describe 'PUT /api/v1/regions/:id' do
    let!(:region) { create(:region, name: 'Old Name') }
    let(:update_attributes) do
      {
        region: {
          name: 'Updated Name',
          is_active: false
        }
      }
    end

    context 'when admin authenticated' do
      it 'updates the region' do
        put "/api/v1/regions/#{region.id}",
            params: update_attributes.to_json,
            headers: admin_headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(200)
        expect(json['name']).to eq('Updated Name')
        expect(json['is_active']).to be false

        region.reload
        expect(region.name).to eq('Updated Name')
        expect(region.is_active).to be false
      end

      it 'returns validation errors for invalid data' do
        put "/api/v1/regions/#{region.id}",
            params: { region: { name: '' } }.to_json,
            headers: admin_headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(422)
        expect(json).to have_key('errors')
      end
    end

    context 'when region does not exist' do
      it 'returns 404' do
        put '/api/v1/regions/999',
            params: update_attributes.to_json,
            headers: admin_headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'DELETE /api/v1/regions/:id' do
    let!(:region) { create(:region) }

    context 'when admin authenticated' do
      context 'when region has no cities' do
        it 'deletes the region' do
          expect {
            delete "/api/v1/regions/#{region.id}",
                   headers: admin_headers
          }.to change(Region, :count).by(-1)

          expect(response).to have_http_status(204)
        end
      end

      context 'when region has cities' do
        let!(:city) { create(:city, region: region) }

        it 'returns unprocessable entity' do
          delete "/api/v1/regions/#{region.id}",
                 headers: admin_headers

          expect(response).to have_http_status(422)
          expect(json).to have_key('error')
        end
      end
    end

    context 'when region does not exist' do
      it 'returns 404' do
        delete '/api/v1/regions/999',
               headers: admin_headers

        expect(response).to have_http_status(404)
      end
    end
  end
end
