require 'rails_helper'

RSpec.describe 'Supplier Analytics API', type: :request do
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
  let!(:partner_user) { create(:user, role: partner_role) }
  let!(:partner) { create(:partner, user: partner_user) }

  let!(:products) do
    5.times.map do |i|
      create(:supplier_tire_product, supplier: supplier, original_brand: "Brand#{i}")
    end
  end

  let!(:completed_orders) do
    3.times.map do
      order = create(:tire_order, :delivered, supplier: supplier, partner: partner)
      create(:tire_order_item, tire_order: order, supplier_tire_product: products.sample, quantity: 4, price_at_order: 1000)
      order
    end
  end

  let!(:pending_order) do
    order = create(:tire_order, supplier: supplier, partner: partner)
    create(:tire_order_item, tire_order: order, supplier_tire_product: products.first, quantity: 2, price_at_order: 1500)
    order
  end

  describe 'GET /api/v1/suppliers/:supplier_id/analytics' do
    context 'as supplier' do
      it 'returns analytics overview' do
        get "/api/v1/suppliers/#{supplier.id}/analytics", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json).to have_key('overview')
        expect(json).to have_key('sales_by_period')
        expect(json).to have_key('top_products')
        expect(json).to have_key('top_partners')
        expect(json).to have_key('category_breakdown')
        expect(json).to have_key('period')
      end

      it 'calculates overview stats correctly' do
        get "/api/v1/suppliers/#{supplier.id}/analytics", headers: headers

        json = JSON.parse(response.body)
        overview = json['overview']

        expect(overview['total_orders']).to be >= 4 # 3 completed + 1 pending (factory may add more)
        expect(overview['completed_orders']).to be >= 3
        expect(overview['total_revenue']).to be_a(Numeric)
        expect(overview['total_revenue']).to be > 0
        expect(overview['total_items_sold']).to be_a(Integer)
        expect(overview['total_items_sold']).to be > 0
        expect(overview['average_order_value']).to be_a(Numeric)
        expect(overview['conversion_rate']).to be_a(Numeric)
      end

      it 'supports date range filter' do
        get "/api/v1/suppliers/#{supplier.id}/analytics",
            params: { date_from: 7.days.ago.to_date.to_s, date_to: Date.current.to_s },
            headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['period']['from']).to eq(7.days.ago.to_date.to_s)
        expect(json['period']['to']).to eq(Date.current.to_s)
      end

      it 'supports grouping parameter' do
        get "/api/v1/suppliers/#{supplier.id}/analytics",
            params: { grouping: 'week' },
            headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['period']['grouping']).to eq('week')
      end
    end

    context 'as admin' do
      it 'can access any supplier analytics' do
        get "/api/v1/suppliers/#{supplier.id}/analytics", headers: admin_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'as client' do
      it 'returns forbidden' do
        get "/api/v1/suppliers/#{supplier.id}/analytics", headers: client_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get "/api/v1/suppliers/#{supplier.id}/analytics"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/suppliers/:supplier_id/analytics/sales' do
    it 'returns sales by period' do
      get "/api/v1/suppliers/#{supplier.id}/analytics/sales", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to have_key('sales_by_period')
      expect(json).to have_key('period')
      expect(json['sales_by_period']).to be_an(Array)
    end

    it 'groups by month when specified' do
      get "/api/v1/suppliers/#{supplier.id}/analytics/sales",
          params: { grouping: 'month' },
          headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['period']['grouping']).to eq('month')
    end
  end

  describe 'GET /api/v1/suppliers/:supplier_id/analytics/products' do
    it 'returns top products' do
      get "/api/v1/suppliers/#{supplier.id}/analytics/products", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to have_key('top_products')
      expect(json).to have_key('total_products')
      expect(json).to have_key('active_products')
      expect(json['total_products']).to eq(5)
    end

    it 'respects limit parameter' do
      get "/api/v1/suppliers/#{supplier.id}/analytics/products",
          params: { limit: 3 },
          headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['top_products'].length).to be <= 3
    end
  end

  describe 'GET /api/v1/suppliers/:supplier_id/analytics/partners' do
    it 'returns top buying partners' do
      get "/api/v1/suppliers/#{supplier.id}/analytics/partners", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to have_key('top_partners')
      expect(json).to have_key('total_partners')
      expect(json['top_partners']).to be_an(Array)
    end

    it 'includes partner details' do
      get "/api/v1/suppliers/#{supplier.id}/analytics/partners", headers: headers

      json = JSON.parse(response.body)
      top_partner = json['top_partners'].first

      expect(top_partner).to have_key('partner_id')
      expect(top_partner).to have_key('company_name')
      expect(top_partner).to have_key('orders_count')
      expect(top_partner).to have_key('total_spent')
    end
  end

  describe 'GET /api/v1/suppliers/:supplier_id/analytics/categories' do
    it 'returns category and season breakdown' do
      get "/api/v1/suppliers/#{supplier.id}/analytics/categories", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to have_key('category_breakdown')
      expect(json).to have_key('season_breakdown')
      expect(json['category_breakdown']).to be_an(Array)
      expect(json['season_breakdown']).to be_an(Array)
    end

    it 'includes brand data in breakdown' do
      get "/api/v1/suppliers/#{supplier.id}/analytics/categories", headers: headers

      json = JSON.parse(response.body)

      if json['category_breakdown'].any?
        category = json['category_breakdown'].first
        expect(category).to have_key('brand')
        expect(category).to have_key('total_quantity')
        expect(category).to have_key('total_revenue')
      end
    end
  end

  describe 'error handling' do
    it 'returns bad request for invalid date format' do
      get "/api/v1/suppliers/#{supplier.id}/analytics",
          params: { date_from: 'invalid-date' },
          headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns not found for non-existent supplier' do
      get "/api/v1/suppliers/999999/analytics", headers: admin_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
