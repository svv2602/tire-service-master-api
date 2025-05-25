require 'rails_helper'

RSpec.describe 'API V1 ServicePointPhotos', type: :request do
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
    UserRole.find_by(name: 'admin') || create(:user_role, name: 'admin', description: 'Admin role')
  end
  
  let(:client_user) { create(:user, role_id: client_role.id) }
  let(:client_headers) { generate_auth_headers(client_user) }
  
  let(:partner_user) { create(:user, role_id: partner_role.id) }
  let(:partner) { create(:partner, user: partner_user) }
  let(:partner_headers) { generate_auth_headers(partner_user) }
  
  let(:admin_user) { create(:user, role_id: admin_role.id) }
  let(:admin_headers) { generate_auth_headers(admin_user) }
  
  let(:service_point) { create(:service_point, partner: partner) }
  let(:photos) { create_list(:service_point_photo, 3, service_point: service_point) }
  let(:photo_id) { photos.first.id }
  
  before(:each) do
    # Ensure the users have the right roles
    client_user.update!(role_id: client_role.id) unless client_user.role_id == client_role.id
    partner_user.update!(role_id: partner_role.id) unless partner_user.role_id == partner_role.id
    admin_user.update!(role_id: admin_role.id) unless admin_user.role_id == admin_role.id
  end
  
  describe 'GET /api/v1/service_points/:service_point_id/photos' do
    context 'authorized access' do
      before do
        # Create photos for the test
        photos
        
        get "/api/v1/service_points/#{service_point.id}/photos", headers: client_headers
      end
      
      it 'returns photos' do
        expect(json).not_to be_empty
        expect(json.size).to eq(3)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns photos with correct attributes' do
        expect(json.first).to include('id', 'photo_url', 'sort_order')
      end
    end
    
    context 'when service point does not exist' do
      before do
        get '/api/v1/service_points/999/photos', headers: client_headers
      end
      
      it 'returns status code 404' do
        expect(response).to have_http_status(404)
      end
      
      it 'returns a not found message' do
        expect(response.body).to match(/Resource not found/)
      end
    end
  end
  
  describe 'GET /api/v1/service_points/:service_point_id/photos/:id' do
    context 'authorized access' do
      before do
        # Create photos for the test
        photos
        
        get "/api/v1/service_points/#{service_point.id}/photos/#{photo_id}", headers: client_headers
      end
      
      it 'returns photo' do
        expect(json).not_to be_empty
        expect(json['id']).to eq(photo_id)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end
    
    context 'when photo does not exist' do
      before do
        get "/api/v1/service_points/#{service_point.id}/photos/999", headers: client_headers
      end
      
      it 'returns status code 404' do
        expect(response).to have_http_status(404)
      end
      
      it 'returns a not found message' do
        expect(response.body).to match(/Resource not found/)
      end
    end
  end
  
  describe 'POST /api/v1/service_points/:service_point_id/photos' do
    let(:valid_attributes) do
      {
        sort_order: 1,
        photo_url: "https://example.com/photos/#{SecureRandom.hex(8)}.jpg"
      }
    end
    
    context 'when request is valid' do
      context 'as a partner' do
        before do
          post "/api/v1/service_points/#{service_point.id}/photos",
               params: valid_attributes.to_json, 
               headers: partner_headers
        end
        
        it 'creates a photo' do
          expect(json['photo_url']).to eq(valid_attributes[:photo_url])
        end
        
        it 'returns status code 201' do
          expect(response).to have_http_status(201)
        end
      end
      
      context 'as an admin' do
        before do
          post "/api/v1/service_points/#{service_point.id}/photos",
               params: valid_attributes.to_json, 
               headers: admin_headers
        end
        
        it 'creates a photo' do
          expect(json['photo_url']).to eq(valid_attributes[:photo_url])
        end
        
        it 'returns status code 201' do
          expect(response).to have_http_status(201)
        end
      end
    end
    
    context 'when request is invalid' do
      before do
        post "/api/v1/service_points/#{service_point.id}/photos",
             params: { sort_order: 1 }.to_json,
             headers: partner_headers
      end
      
      it 'returns status code 422' do
        expect(response).to have_http_status(422)
      end
      
      it 'returns a validation failure message' do
        expect(json['errors']).to be_present
      end
    end
    
    context 'with invalid permissions' do
      before do
        post "/api/v1/service_points/#{service_point.id}/photos",
             params: valid_attributes.to_json, 
             headers: client_headers
      end
      
      it 'returns status code 401' do
        expect(response).to have_http_status(401)
      end
    end
  end
  
  describe 'PATCH /api/v1/service_points/:service_point_id/photos/:id' do
    let(:valid_attributes) { { sort_order: 2 } }
    
    before do
      # Create photos for the test
      photos
    end
    
    context 'as a partner' do
      before do
        patch "/api/v1/service_points/#{service_point.id}/photos/#{photo_id}",
              params: valid_attributes.to_json, 
              headers: partner_headers
      end
      
      it 'updates the photo' do
        expect(json['sort_order']).to eq(2)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end
    
    context 'as an admin' do
      before do
        patch "/api/v1/service_points/#{service_point.id}/photos/#{photo_id}",
              params: valid_attributes.to_json, 
              headers: admin_headers
      end
      
      it 'updates the photo' do
        expect(json['sort_order']).to eq(2)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end
    
    context 'with invalid permissions' do
      before do
        patch "/api/v1/service_points/#{service_point.id}/photos/#{photo_id}",
              params: valid_attributes.to_json, 
              headers: client_headers
      end
      
      it 'returns status code 401' do
        expect(response).to have_http_status(401)
      end
    end
  end
  
  describe 'DELETE /api/v1/service_points/:service_point_id/photos/:id' do
    before do
      # Create photos for the test
      photos
    end
    
    context 'as a partner' do
      before do
        delete "/api/v1/service_points/#{service_point.id}/photos/#{photo_id}",
              headers: partner_headers
      end
      
      it 'returns success message' do
        expect(json['message']).to match(/successfully/)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end
    
    context 'as an admin' do
      before do
        delete "/api/v1/service_points/#{service_point.id}/photos/#{photo_id}",
              headers: admin_headers
      end
      
      it 'returns success message' do
        expect(json['message']).to match(/successfully/)
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end
    
    context 'with invalid permissions' do
      before do
        delete "/api/v1/service_points/#{service_point.id}/photos/#{photo_id}",
              headers: client_headers
      end
      
      it 'returns status code 401' do
        expect(response).to have_http_status(401)
      end
    end
  end
end
