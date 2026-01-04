require 'rails_helper'

RSpec.describe 'Supplier Orders API', type: :request do
  let(:supplier_role) { UserRole.find_or_create_by!(name: 'supplier') }
  let(:supplier_user) { create(:user, role: supplier_role) }
  let(:supplier) { create(:supplier, user: supplier_user) }
  let(:headers) { auth_headers(supplier_user) }

  let(:admin_role) { UserRole.find_or_create_by!(name: 'admin') }
  let(:admin_user) { create(:user, role: admin_role) }
  let(:admin_headers) { auth_headers(admin_user) }

  let(:client_role) { UserRole.find_or_create_by!(name: 'client') }
  let(:client_user) { create(:user, role: client_role) }
  let(:client_headers) { auth_headers(client_user) }

  let!(:product) { create(:supplier_tire_product, supplier: supplier) }
  let!(:submitted_order) do
    order = create(:tire_order, supplier: supplier, status: 'submitted')
    create(:tire_order_item, tire_order: order, supplier_tire_product: product)
    order.reload
  end
  let!(:confirmed_order) do
    order = create(:tire_order, supplier: supplier, status: 'confirmed')
    create(:tire_order_item, tire_order: order, supplier_tire_product: create(:supplier_tire_product, supplier: supplier))
    order.reload
  end
  let!(:processing_order) do
    order = create(:tire_order, supplier: supplier, status: 'processing')
    create(:tire_order_item, tire_order: order, supplier_tire_product: create(:supplier_tire_product, supplier: supplier))
    order.reload
  end

  describe 'GET /api/v1/suppliers/:supplier_id/orders' do
    context 'as supplier' do
      it 'returns list of orders' do
        get "/api/v1/suppliers/#{supplier.id}/orders", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['orders']).to be_an(Array)
        expect(json['orders'].length).to be >= 3
        expect(json['pagination']).to be_present
        expect(json['stats']).to be_present
      end

      it 'filters by status' do
        get "/api/v1/suppliers/#{supplier.id}/orders", params: { status: 'submitted' }, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['orders'].all? { |o| o['status'] == 'submitted' }).to be true
      end

      it 'searches by client name' do
        get "/api/v1/suppliers/#{supplier.id}/orders", params: { search: submitted_order.client_name }, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['orders']).not_to be_empty
      end
    end

    context 'as admin' do
      it 'can access any supplier orders' do
        get "/api/v1/suppliers/#{supplier.id}/orders", headers: admin_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'as client' do
      it 'returns forbidden' do
        get "/api/v1/suppliers/#{supplier.id}/orders", headers: client_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get "/api/v1/suppliers/#{supplier.id}/orders"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/suppliers/:supplier_id/orders/:id' do
    context 'as supplier' do
      it 'returns order details' do
        get "/api/v1/suppliers/#{supplier.id}/orders/#{submitted_order.id}", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['order']['id']).to eq(submitted_order.id)
        expect(json['order']['items']).to be_an(Array)
        expect(json['order']['available_actions']).to be_an(Array)
      end

      it 'returns not found for another supplier order' do
        other_supplier = create(:supplier)
        other_order = create(:tire_order, :submitted, supplier: other_supplier)

        get "/api/v1/suppliers/#{supplier.id}/orders/#{other_order.id}", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /api/v1/suppliers/:supplier_id/orders/:id' do
    context 'as supplier' do
      it 'updates notes and tracking number' do
        patch "/api/v1/suppliers/#{supplier.id}/orders/#{submitted_order.id}",
              params: { order: { notes: 'Test notes', tracking_number: 'TRACK123' } },
              headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(submitted_order.reload.notes).to eq('Test notes')
        expect(submitted_order.tracking_number).to eq('TRACK123')
      end
    end
  end

  describe 'POST /api/v1/suppliers/:supplier_id/orders/:id/confirm' do
    context 'as supplier' do
      it 'confirms submitted order' do
        post "/api/v1/suppliers/#{supplier.id}/orders/#{submitted_order.id}/confirm", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(submitted_order.reload.status).to eq('confirmed')
      end

      it 'fails for already confirmed order (returns forbidden from policy)' do
        post "/api/v1/suppliers/#{supplier.id}/orders/#{confirmed_order.id}/confirm", headers: headers

        # Policy returns false for confirm? when order is already confirmed
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/suppliers/:supplier_id/orders/:id/start_processing' do
    context 'as supplier' do
      it 'starts processing confirmed order' do
        post "/api/v1/suppliers/#{supplier.id}/orders/#{confirmed_order.id}/start_processing", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(confirmed_order.reload.status).to eq('processing')
      end
    end
  end

  describe 'POST /api/v1/suppliers/:supplier_id/orders/:id/ship' do
    context 'as supplier' do
      it 'ships processing order with tracking number' do
        post "/api/v1/suppliers/#{supplier.id}/orders/#{processing_order.id}/ship",
             params: { tracking_number: 'UA987654321' },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true

        processing_order.reload
        expect(processing_order.status).to eq('shipped')
        expect(processing_order.tracking_number).to eq('UA987654321')
        # shipped_at is set by AASM callback
        expect(processing_order.shipped_at).to be_present
      end
    end
  end

  describe 'POST /api/v1/suppliers/:supplier_id/orders/:id/cancel' do
    context 'as supplier' do
      it 'cancels submitted order' do
        post "/api/v1/suppliers/#{supplier.id}/orders/#{submitted_order.id}/cancel", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(submitted_order.reload.status).to eq('cancelled')
      end
    end
  end
end
