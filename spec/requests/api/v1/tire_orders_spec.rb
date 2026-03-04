# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tire Orders API', type: :request do
  let(:client_role) { UserRole.find_or_create_by!(name: 'client') { |r| r.description = 'Client role' } }
  let(:admin_role) { UserRole.find_or_create_by!(name: 'admin') { |r| r.description = 'Admin role' } }

  let(:client_user) { create(:user, role: client_role) }
  let!(:client) { create(:client, user: client_user) }
  let(:client_headers) { auth_headers(client_user) }

  let(:admin_user) { create(:user, role: admin_role) }
  let!(:admin_record) { Administrator.create!(user: admin_user) }
  let(:admin_headers) { auth_headers(admin_user) }

  let(:other_user) { create(:user, role: client_role) }
  let!(:other_client) { create(:client, user: other_user) }
  let(:other_headers) { auth_headers(other_user) }

  let(:supplier) { create(:supplier) }
  let(:product) { create(:supplier_tire_product, supplier: supplier) }

  let(:json_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  # Helper to create tire order with items
  def create_order_with_items(user:, status: 'submitted', supplier_ref: supplier)
    order = create(:tire_order, user: user, supplier: supplier_ref, status: status, skip_broadcasts: true)
    create(:tire_order_item, tire_order: order, supplier_tire_product: create(:supplier_tire_product, supplier: supplier_ref))
    order.reload
  end

  describe 'GET /api/v1/tire_orders' do
    context 'as authenticated client' do
      let!(:submitted_order) { create_order_with_items(user: client_user, status: 'submitted') }
      let!(:confirmed_order) { create_order_with_items(user: client_user, status: 'confirmed') }
      let!(:draft_order) { create(:tire_order, user: client_user, supplier: supplier, status: 'draft', skip_broadcasts: true) }
      let!(:other_order) { create_order_with_items(user: other_user, status: 'submitted') }

      it 'returns only current user orders excluding drafts' do
        get '/api/v1/tire_orders', headers: client_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['orders']).to be_an(Array)
        order_ids = body['orders'].map { |o| o['id'] }
        expect(order_ids).to include(submitted_order.id, confirmed_order.id)
        expect(order_ids).not_to include(draft_order.id)
        expect(order_ids).not_to include(other_order.id)
      end

      it 'filters by status' do
        get '/api/v1/tire_orders', params: { status: 'submitted' }, headers: client_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        statuses = body['orders'].map { |o| o['status'] }
        expect(statuses).to all(eq('submitted'))
      end

      it 'includes pagination metadata' do
        get '/api/v1/tire_orders', headers: client_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['pagination']).to include(
          'current_page', 'per_page', 'total_count', 'total_pages'
        )
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/v1/tire_orders'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/tire_orders/:id' do
    let!(:order) { create_order_with_items(user: client_user, status: 'submitted') }

    context 'as order owner' do
      it 'returns the order details' do
        get "/api/v1/tire_orders/#{order.id}", headers: client_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['order']['id']).to eq(order.id)
        expect(body['order']['status']).to eq('submitted')
        expect(body['order']['items']).to be_an(Array)
      end
    end

    context 'as admin' do
      it 'can access any order' do
        get "/api/v1/tire_orders/#{order.id}", headers: admin_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'as another user' do
      it 'returns forbidden' do
        get "/api/v1/tire_orders/#{order.id}", headers: other_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'for non-existing order' do
      it 'returns not found' do
        get '/api/v1/tire_orders/999999', headers: client_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /api/v1/tire_orders/:id/cancel' do
    context 'cancellable order (submitted)' do
      let!(:order) { create_order_with_items(user: client_user, status: 'submitted') }

      it 'cancels the order' do
        patch "/api/v1/tire_orders/#{order.id}/cancel", headers: client_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['message']).to include('отменен')
        expect(order.reload.status).to eq('cancelled')
      end
    end

    context 'non-cancellable order (delivered)' do
      let!(:delivered_order) { create_order_with_items(user: client_user, status: 'delivered') }

      it 'returns forbidden' do
        patch "/api/v1/tire_orders/#{delivered_order.id}/cancel", headers: client_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'admin can cancel shipped orders' do
      let!(:shipped_order) { create_order_with_items(user: client_user, status: 'shipped') }

      before { shipped_order.update_columns(shipped_at: Time.current, tracking_number: 'ABC123') }

      it 'allows admin to cancel shipped order' do
        patch "/api/v1/tire_orders/#{shipped_order.id}/cancel", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(shipped_order.reload.status).to eq('cancelled')
      end
    end
  end

  describe 'GET /api/v1/tire_orders/all (admin only)' do
    let!(:order1) { create_order_with_items(user: client_user, status: 'submitted') }
    let!(:order2) { create_order_with_items(user: other_user, status: 'confirmed') }

    context 'as admin' do
      it 'returns all non-draft orders' do
        get '/api/v1/tire_orders/all', headers: admin_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['orders']).to be_an(Array)
        expect(body['orders'].length).to be >= 2
      end
    end

    context 'as regular client' do
      it 'returns forbidden' do
        get '/api/v1/tire_orders/all', headers: client_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
