require 'rails_helper'

RSpec.describe 'Supplier Clients API', type: :request do
  let!(:supplier_role) { UserRole.find_or_create_by!(name: 'supplier') }
  let!(:supplier_user) { create(:user, role: supplier_role) }
  let!(:supplier) { create(:supplier, user: supplier_user) }
  let(:headers) { auth_headers(supplier_user.reload) }

  let!(:admin_role) { UserRole.find_or_create_by!(name: 'admin') }
  let!(:admin_user) { create(:user, role: admin_role) }
  let(:admin_headers) { auth_headers(admin_user.reload) }

  let!(:client_role) { UserRole.find_or_create_by!(name: 'client') }
  let!(:client_user) { create(:user, role: client_role) }
  let(:client_headers) { auth_headers(client_user.reload) }

  let!(:partner_role) { UserRole.find_or_create_by!(name: 'partner') }
  let!(:partner_user1) { create(:user, role: partner_role) }
  let!(:partner1) { create(:partner, user: partner_user1, company_name: 'Partner One') }

  let!(:partner_user2) { create(:user, role: partner_role) }
  let!(:partner2) { create(:partner, user: partner_user2, company_name: 'Partner Two') }

  let!(:products) { create_list(:supplier_tire_product, 3, supplier: supplier) }

  let!(:partner1_orders) do
    3.times.map do
      order = create(:tire_order, :delivered, supplier: supplier, partner: partner1)
      create(:tire_order_item, tire_order: order, supplier_tire_product: products.first, quantity: 2, price_at_order: 1000)
      order
    end
  end

  let!(:partner2_orders) do
    2.times.map do
      order = create(:tire_order, :delivered, supplier: supplier, partner: partner2)
      create(:tire_order_item, tire_order: order, supplier_tire_product: products.first, quantity: 5, price_at_order: 2000)
      order
    end
  end

  describe 'GET /api/v1/suppliers/:supplier_id/clients' do
    context 'as supplier' do
      it 'returns list of clients' do
        get "/api/v1/suppliers/#{supplier.id}/clients", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json).to have_key('clients')
        expect(json).to have_key('pagination')
        expect(json).to have_key('stats')
        expect(json['clients']).to be_an(Array)
        expect(json['clients'].length).to eq(2)
      end

      it 'includes client aggregations' do
        get "/api/v1/suppliers/#{supplier.id}/clients", headers: headers

        json = JSON.parse(response.body)
        client = json['clients'].first

        expect(client).to have_key('id')
        expect(client).to have_key('company_name')
        expect(client).to have_key('orders_count')
        expect(client).to have_key('total_spent')
        expect(client).to have_key('total_items')
        expect(client).to have_key('last_order_at')
      end

      it 'sorts by total_spent by default' do
        get "/api/v1/suppliers/#{supplier.id}/clients", headers: headers

        json = JSON.parse(response.body)
        clients = json['clients']

        # Verify that clients are sorted by total_spent (descending)
        total_spent_values = clients.map { |c| c['total_spent'] }
        expect(total_spent_values).to eq(total_spent_values.sort.reverse)
      end

      it 'supports sorting by orders_count' do
        get "/api/v1/suppliers/#{supplier.id}/clients",
            params: { sort: 'orders_count_desc' },
            headers: headers

        json = JSON.parse(response.body)
        clients = json['clients']

        # Verify that clients are sorted by orders_count (descending)
        orders_count_values = clients.map { |c| c['orders_count'] }
        expect(orders_count_values).to eq(orders_count_values.sort.reverse)
      end

      it 'supports pagination' do
        get "/api/v1/suppliers/#{supplier.id}/clients",
            params: { page: 1, per_page: 1 },
            headers: headers

        json = JSON.parse(response.body)

        expect(json['clients'].length).to eq(1)
        expect(json['pagination']['current_page']).to eq(1)
        expect(json['pagination']['per_page']).to eq(1)
        expect(json['pagination']['total_pages']).to eq(2)
        expect(json['pagination']['total_count']).to eq(2)
      end
    end

    context 'as admin' do
      it 'can access any supplier clients' do
        get "/api/v1/suppliers/#{supplier.id}/clients", headers: admin_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'as client' do
      it 'returns forbidden' do
        get "/api/v1/suppliers/#{supplier.id}/clients", headers: client_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get "/api/v1/suppliers/#{supplier.id}/clients"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/suppliers/:supplier_id/clients/:id' do
    context 'as supplier' do
      it 'returns client details' do
        get "/api/v1/suppliers/#{supplier.id}/clients/#{partner1.id}", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json).to have_key('client')
        expect(json).to have_key('orders')
        expect(json).to have_key('stats')
      end

      it 'includes client info' do
        get "/api/v1/suppliers/#{supplier.id}/clients/#{partner1.id}", headers: headers

        json = JSON.parse(response.body)
        client = json['client']

        expect(client['id']).to eq(partner1.id)
        expect(client['company_name']).to eq('Partner One')
        expect(client).to have_key('contact_person')
        expect(client).to have_key('email')
        expect(client).to have_key('phone')
      end

      it 'includes order history' do
        get "/api/v1/suppliers/#{supplier.id}/clients/#{partner1.id}", headers: headers

        json = JSON.parse(response.body)
        orders = json['orders']

        expect(orders).to be_an(Array)
        expect(orders.length).to be >= 3

        order = orders.first
        expect(order).to have_key('id')
        expect(order).to have_key('status')
        expect(order).to have_key('total')
        expect(order).to have_key('created_at')
      end

      it 'includes client stats' do
        get "/api/v1/suppliers/#{supplier.id}/clients/#{partner1.id}", headers: headers

        json = JSON.parse(response.body)
        stats = json['stats']

        expect(stats).to have_key('total_orders')
        expect(stats).to have_key('completed_orders')
        expect(stats).to have_key('total_spent')
        expect(stats).to have_key('average_order_value')
        expect(stats['total_orders']).to be >= 3
      end
    end

    context 'with non-existent client' do
      it 'returns not found' do
        get "/api/v1/suppliers/#{supplier.id}/clients/999999", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with partner who never ordered' do
      let!(:partner_user3) { create(:user, role: partner_role) }
      let!(:partner3) { create(:partner, user: partner_user3) }

      it 'returns not found' do
        get "/api/v1/suppliers/#{supplier.id}/clients/#{partner3.id}", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
