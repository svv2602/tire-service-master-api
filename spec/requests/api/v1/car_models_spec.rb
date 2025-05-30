require 'rails_helper'

RSpec.describe 'API V1 Car Models', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:car_brand) { create(:car_brand) }
  let(:headers) { valid_headers(admin) }

  describe 'GET /api/v1/car_brands/:car_brand_id/car_models' do
    let!(:car_models) { create_list(:car_model, 3, brand: car_brand) }
    let!(:other_models) { create_list(:car_model, 2) }

    it 'returns car models for specific brand' do
      get "/api/v1/car_brands/#{car_brand.id}/car_models"
      expect(response).to have_http_status(:ok)
      expect(json['car_models'].length).to eq(3)
      expect(json['car_models'].map { |m| m['brand_id'] }).to all(eq(car_brand.id))
    end

    context 'with query params' do
      let!(:active_model) { create(:car_model, brand: car_brand, name: 'Active Model', is_active: true) }
      let!(:inactive_model) { create(:car_model, brand: car_brand, name: 'Inactive Model', is_active: false) }

      it 'filters by active status' do
        get "/api/v1/car_brands/#{car_brand.id}/car_models", params: { active: true }
        expect(json['car_models'].map { |m| m['name'] }).to include('Active Model')
        expect(json['car_models'].map { |m| m['name'] }).not_to include('Inactive Model')
      end

      it 'searches by name' do
        get "/api/v1/car_brands/#{car_brand.id}/car_models", params: { query: 'Active' }
        expect(json['car_models'].length).to eq(1)
        expect(json['car_models'].first['name']).to eq('Active Model')
      end
    end
  end

  describe 'POST /api/v1/car_brands/:car_brand_id/car_models' do
    let(:valid_attributes) { { car_model: { name: 'New Model', is_active: true } } }

    context 'when admin authenticated' do
      it 'creates a new car model' do
        expect {
          post "/api/v1/car_brands/#{car_brand.id}/car_models",
               params: valid_attributes,
               headers: headers
        }.to change(CarModel, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json['name']).to eq('New Model')
        expect(json['brand_id']).to eq(car_brand.id)
      end

      it 'returns validation errors for invalid data' do
        post "/api/v1/car_brands/#{car_brand.id}/car_models",
             params: { car_model: { name: '' } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json).to have_key('errors')
      end
    end

    context 'when not authenticated as admin' do
      it 'returns unauthorized' do
        post "/api/v1/car_brands/#{car_brand.id}/car_models",
             params: valid_attributes

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/car_brands/:car_brand_id/car_models/:id' do
    let!(:car_model) { create(:car_model, brand: car_brand) }
    let(:valid_attributes) { { car_model: { name: 'Updated Model' } } }

    context 'when admin authenticated' do
      it 'updates the car model' do
        put "/api/v1/car_brands/#{car_brand.id}/car_models/#{car_model.id}",
            params: valid_attributes,
            headers: headers

        expect(response).to have_http_status(:ok)
        expect(json['name']).to eq('Updated Model')
      end

      it 'returns validation errors for invalid data' do
        put "/api/v1/car_brands/#{car_brand.id}/car_models/#{car_model.id}",
            params: { car_model: { name: '' } },
            headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json).to have_key('errors')
      end
    end
  end

  describe 'DELETE /api/v1/car_brands/:car_brand_id/car_models/:id' do
    let!(:car_model) { create(:car_model, brand: car_brand) }

    context 'when admin authenticated' do
      it 'deletes the car model' do
        expect {
          delete "/api/v1/car_brands/#{car_brand.id}/car_models/#{car_model.id}",
                 headers: headers
        }.to change(CarModel, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      context 'when model has associated client cars' do
        before { create(:client_car, car_model: car_model) }

        it 'returns unprocessable_entity status' do
          delete "/api/v1/car_brands/#{car_brand.id}/car_models/#{car_model.id}",
                 headers: headers

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json['error']).to include('используется в автомобилях клиентов')
        end
      end
    end
  end
end 