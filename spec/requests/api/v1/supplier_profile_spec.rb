require 'rails_helper'

RSpec.describe 'Supplier Profile API', type: :request do
  let(:supplier_role) { UserRole.find_or_create_by!(name: 'supplier') }
  let(:supplier_user) { create(:user, role: supplier_role) }
  let(:supplier) { create(:supplier, user: supplier_user) }
  let(:headers) { auth_headers(supplier_user) }

  let(:admin_role) { UserRole.find_or_create_by!(name: 'admin') }
  let(:admin_user) { create(:user, role: admin_role) }
  let(:admin_headers) { auth_headers(admin_user) }

  let(:other_supplier_user) { create(:user, role: supplier_role) }
  let(:other_supplier) { create(:supplier, user: other_supplier_user) }
  let(:other_headers) { auth_headers(other_supplier_user) }

  describe 'GET /api/v1/suppliers/:supplier_id/profile' do
    context 'as supplier' do
      it 'returns profile for own supplier' do
        get "/api/v1/suppliers/#{supplier.id}/profile", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:profile]).to include(
          id: supplier.id,
          firm_id: supplier.firm_id,
          name: supplier.name
        )
        expect(json_response[:profile][:api_key]).to eq(supplier.api_key)
      end

      it 'returns forbidden for other supplier' do
        get "/api/v1/suppliers/#{other_supplier.id}/profile", headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as admin' do
      it 'returns profile for any supplier' do
        get "/api/v1/suppliers/#{supplier.id}/profile", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:profile][:id]).to eq(supplier.id)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get "/api/v1/suppliers/#{supplier.id}/profile"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/suppliers/:supplier_id/profile' do
    let(:valid_params) do
      {
        profile: {
          name: 'Updated Name',
          email: 'updated@email.com',
          phone: '+380501234567',
          description: 'Updated description',
          website: 'https://updated.com',
          contact_person: 'John Doe',
          address: '123 Test Street'
        }
      }
    end

    context 'as supplier' do
      it 'updates own profile' do
        patch "/api/v1/suppliers/#{supplier.id}/profile",
              params: valid_params,
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:success]).to be true
        expect(json_response[:profile][:name]).to eq('Updated Name')
        expect(json_response[:profile][:email]).to eq('updated@email.com')

        supplier.reload
        expect(supplier.name).to eq('Updated Name')
        expect(supplier.email).to eq('updated@email.com')
      end

      it 'returns forbidden for other supplier' do
        patch "/api/v1/suppliers/#{other_supplier.id}/profile",
              params: valid_params,
              headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as admin' do
      it 'updates any supplier profile' do
        patch "/api/v1/suppliers/#{supplier.id}/profile",
              params: valid_params,
              headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:success]).to be true
      end
    end
  end

  describe 'POST /api/v1/suppliers/:supplier_id/profile/regenerate_api_key' do
    context 'as supplier' do
      it 'regenerates API key for own supplier' do
        old_api_key = supplier.api_key

        post "/api/v1/suppliers/#{supplier.id}/profile/regenerate_api_key",
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:success]).to be true
        expect(json_response[:profile][:api_key]).not_to eq(old_api_key)

        supplier.reload
        expect(supplier.api_key).not_to eq(old_api_key)
      end

      it 'returns forbidden for other supplier' do
        post "/api/v1/suppliers/#{other_supplier.id}/profile/regenerate_api_key",
             headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as admin' do
      it 'regenerates API key for any supplier' do
        old_api_key = supplier.api_key

        post "/api/v1/suppliers/#{supplier.id}/profile/regenerate_api_key",
             headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:profile][:api_key]).not_to eq(old_api_key)
      end
    end
  end
end
