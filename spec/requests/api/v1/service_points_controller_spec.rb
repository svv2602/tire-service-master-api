# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::ServicePoints', type: :request do
  # Setup roles
  let!(:client_role) { UserRole.find_or_create_by!(name: 'client', description: 'Client role') }
  let!(:admin_role) { UserRole.find_or_create_by!(name: 'admin', description: 'Admin role') }
  let!(:partner_role) { UserRole.find_or_create_by!(name: 'partner', description: 'Partner role') }

  # Use factories for setup
  let!(:admin_user) { create(:admin) }
  let!(:partner_user) { create(:partner_user) }
  let!(:partner) { partner_user.partner }
  let!(:other_partner_user) { create(:partner_user) }
  let!(:other_partner) { other_partner_user.partner }
  let!(:service_point) { create(:service_point, partner: partner, is_active: true) }
  let!(:inactive_service_point) { create(:service_point, partner: partner, is_active: false) }
  let!(:other_service_point) { create(:service_point, partner: other_partner, is_active: true) }

  # Auth headers
  let(:admin_headers) { auth_headers(admin_user) }
  let(:partner_headers) { auth_headers(partner_user) }
  let(:other_partner_headers) { auth_headers(other_partner_user) }

  describe 'GET /api/v1/service_points' do
    context 'without authentication (public access)' do
      before { get '/api/v1/service_points' }

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns service points data' do
        expect(json_response).to have_key(:data)
        expect(json_response).to have_key(:pagination)
      end
    end

    context 'with admin authentication' do
      before { get '/api/v1/service_points', headers: admin_headers }

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns all service points' do
        expect(json_response[:data]).to be_an(Array)
      end
    end

    context 'with partner_id filter' do
      before { get '/api/v1/service_points', params: { partner_id: partner.id }, headers: partner_headers }

      it 'returns only partner service points' do
        expect(response).to have_http_status(200)
      end
    end

    context 'with is_active filter' do
      before { get '/api/v1/service_points', params: { is_active: 'true' }, headers: admin_headers }

      it 'returns only active service points' do
        expect(response).to have_http_status(200)
        # All returned service points should be active
        expect(json_response[:data]).to all(include(is_active: true))
      end
    end

    context 'with query search' do
      before { get '/api/v1/service_points', params: { query: service_point.name.first(3) }, headers: admin_headers }

      it 'returns filtered service points' do
        expect(response).to have_http_status(200)
      end
    end
  end

  describe 'GET /api/v1/service_points/:id' do
    context 'without authentication (public access)' do
      before { get "/api/v1/service_points/#{service_point.id}" }

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns the service point' do
        expect(json_response[:id]).to eq(service_point.id)
      end
    end

    context 'when service point does not exist' do
      before { get '/api/v1/service_points/999999', headers: admin_headers }

      it 'returns status 404' do
        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'POST /api/v1/partners/:partner_id/service_points' do
    let(:valid_params) do
      {
        service_point: {
          name: 'New Service Point',
          name_ru: 'Новая сервисная точка',
          name_uk: 'Нова сервісна точка',
          address: '123 Test Street',
          address_ru: 'Тестовый адрес 123, Город',
          address_uk: 'Тестова адреса 123, Місто',
          description: 'Test service point description with more details',
          description_ru: 'Тестовое описание сервисной точки с большими деталями',
          description_uk: 'Тестовий опис сервісної точки з більшими деталями',
          city_id: service_point.city_id,
          contact_phone: '+380671234567',
          is_active: true,
          work_status: 'working',
          latitude: 50.45,
          longitude: 30.52
        }
      }
    end

    context 'when partner creates own service point' do
      before do
        post "/api/v1/partners/#{partner.id}/service_points",
             params: valid_params.to_json,
             headers: partner_headers.merge('Content-Type' => 'application/json')
      end

      it 'returns status 201' do
        expect(response).to have_http_status(201)
      end

      it 'creates the service point' do
        expect(json_response[:name]).to eq('New Service Point')
      end
    end

    context 'when admin creates service point for partner' do
      before do
        post "/api/v1/partners/#{partner.id}/service_points",
             params: valid_params.to_json,
             headers: admin_headers.merge('Content-Type' => 'application/json')
      end

      it 'returns status 201' do
        expect(response).to have_http_status(201)
      end
    end

    context 'without authentication' do
      before do
        post "/api/v1/partners/#{partner.id}/service_points",
             params: valid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }
      end

      it 'returns unauthorized' do
        expect(response).to have_http_status(401)
      end
    end

    context 'when partner tries to create for another partner' do
      before do
        post "/api/v1/partners/#{other_partner.id}/service_points",
             params: valid_params.to_json,
             headers: partner_headers.merge('Content-Type' => 'application/json')
      end

      it 'returns forbidden' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'PUT /api/v1/partners/:partner_id/service_points/:id' do
    let(:update_params) do
      {
        service_point: {
          name: 'Updated Name',
          address: 'Updated Address'
        }
      }
    end

    context 'when partner updates own service point' do
      before do
        put "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
            params: update_params.to_json,
            headers: partner_headers.merge('Content-Type' => 'application/json')
      end

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end

      it 'updates the service point' do
        service_point.reload
        expect(service_point.name).to eq('Updated Name')
      end
    end

    context 'when admin updates service point' do
      before do
        put "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
            params: update_params.to_json,
            headers: admin_headers.merge('Content-Type' => 'application/json')
      end

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'when partner tries to update another partner service point' do
      before do
        put "/api/v1/partners/#{other_partner.id}/service_points/#{other_service_point.id}",
            params: update_params.to_json,
            headers: partner_headers.merge('Content-Type' => 'application/json')
      end

      it 'returns forbidden' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'DELETE /api/v1/partners/:partner_id/service_points/:id' do
    context 'when partner deletes own active service point' do
      before do
        delete "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}",
               headers: partner_headers.merge('Content-Type' => 'application/json')
      end

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end

      it 'deactivates the service point instead of deleting' do
        service_point.reload
        expect(service_point.is_active).to be false
      end

      it 'returns deactivated action message' do
        expect(json_response[:action]).to eq('deactivated')
      end
    end

    context 'when partner deletes own inactive service point (no bookings)' do
      before do
        delete "/api/v1/partners/#{partner.id}/service_points/#{inactive_service_point.id}",
               headers: partner_headers.merge('Content-Type' => 'application/json')
      end

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns deleted action message' do
        expect(json_response[:action]).to eq('deleted')
      end
    end

    context 'when partner tries to delete another partner service point' do
      before do
        delete "/api/v1/partners/#{other_partner.id}/service_points/#{other_service_point.id}",
               headers: partner_headers.merge('Content-Type' => 'application/json')
      end

      it 'returns forbidden' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /api/v1/service_points/search (client_search)' do
    context 'without filters' do
      before { get '/api/v1/service_points/search' }

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns available service points' do
        expect(json_response).to have_key(:data)
        expect(json_response).to have_key(:pagination)
      end
    end

    context 'with city filter' do
      before { get '/api/v1/service_points/search', params: { city_id: service_point.city_id } }

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'with query search' do
      before { get '/api/v1/service_points/search', params: { query: service_point.name.first(3) } }

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end
    end
  end

  describe 'GET /api/v1/service_points/:id/client_details' do
    context 'when service point is available' do
      before do
        # Make sure the service point is available for booking
        service_point.update(is_active: true, work_status: 'working')
        get "/api/v1/service_points/#{service_point.id}/client_details"
      end

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns detailed service point information' do
        expect(json_response[:id]).to eq(service_point.id)
        expect(json_response).to have_key(:name)
        expect(json_response).to have_key(:address)
        expect(json_response).to have_key(:city)
      end
    end
  end

  describe 'GET /api/v1/service_points/work_statuses' do
    before { get '/api/v1/service_points/work_statuses' }

    it 'returns status 200' do
      expect(response).to have_http_status(200)
    end

    it 'returns work status options' do
      expect(json_response).to be_an(Array)
      expect(json_response.first).to have_key(:value)
      expect(json_response.first).to have_key(:label)
    end
  end

  describe 'GET /api/v1/service_points/by_category' do
    let!(:service_category) { create(:service_category) }
    let!(:service_post) { create(:service_post, service_point: service_point, service_category: service_category) }

    context 'with valid category_id' do
      before { get '/api/v1/service_points/by_category', params: { category_id: service_category.id } }

      it 'returns status 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'without category_id' do
      before { get '/api/v1/service_points/by_category' }

      it 'returns bad request' do
        expect(response).to have_http_status(400)
      end
    end
  end

  describe 'GET /api/v1/service_points/regions' do
    before { get '/api/v1/service_points/regions' }

    it 'returns status 200' do
      expect(response).to have_http_status(200)
    end

    it 'returns regions with service points' do
      expect(json_response).to have_key(:data)
      expect(json_response).to have_key(:total)
    end
  end

  describe 'GET /api/v1/service_points/cities' do
    before { get '/api/v1/service_points/cities' }

    it 'returns status 200' do
      expect(response).to have_http_status(200)
    end

    it 'returns cities with service points' do
      expect(json_response).to have_key(:data)
      expect(json_response).to have_key(:total)
    end
  end
end
