require 'rails_helper'

RSpec.describe 'Supplier Dashboard API', type: :request do
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

  before do
    # Create some products
    @products = create_list(:supplier_tire_product, 5, supplier: supplier)

    # Create some orders
    @completed_order = create(:tire_order, :completed, supplier: supplier)
    @submitted_order = create(:tire_order, :submitted, supplier: supplier)
    @processing_order = create(:tire_order, :processing, supplier: supplier)
  end

  describe 'GET /api/v1/suppliers/:supplier_id/dashboard' do
    context 'as supplier' do
      it 'returns dashboard data' do
        get "/api/v1/suppliers/#{supplier.id}/dashboard", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        # Check stats
        expect(json['stats']).to be_present
        expect(json['stats']['total_orders']).to be_a(Integer)
        expect(json['stats']['total_products']).to eq(5)
        expect(json['stats']['pending_orders']).to be_a(Integer)
        expect(json['stats']['total_revenue']).to be_a(Float)
        expect(json['stats']['monthly_revenue']).to be_a(Float)

        # Check recent orders
        expect(json['recent_orders']).to be_an(Array)
        expect(json['recent_orders'].length).to be <= 10

        # Check top products
        expect(json['top_products']).to be_an(Array)

        # Check revenue chart
        expect(json['revenue_chart']).to be_an(Array)
        expect(json['revenue_chart'].length).to eq(31) # 30 days + today
        expect(json['revenue_chart'].first).to have_key('date')
        expect(json['revenue_chart'].first).to have_key('revenue')
      end

      it 'caches stats' do
        # First request
        get "/api/v1/suppliers/#{supplier.id}/dashboard", headers: headers
        expect(response).to have_http_status(:ok)
        first_response = JSON.parse(response.body)

        # Second request should be cached
        get "/api/v1/suppliers/#{supplier.id}/dashboard", headers: headers
        expect(response).to have_http_status(:ok)
        second_response = JSON.parse(response.body)

        expect(first_response['stats']).to eq(second_response['stats'])
      end
    end

    context 'as admin' do
      it 'can access any supplier dashboard' do
        get "/api/v1/suppliers/#{supplier.id}/dashboard", headers: admin_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'as client' do
      it 'returns forbidden' do
        get "/api/v1/suppliers/#{supplier.id}/dashboard", headers: client_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get "/api/v1/suppliers/#{supplier.id}/dashboard"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'stats calculations' do
    before do
      # Create more orders with specific dates for testing
      create(:tire_order, :completed, supplier: supplier, created_at: 1.day.ago)
      create(:tire_order, :completed, supplier: supplier, created_at: 7.days.ago)
      create(:tire_order, :completed, supplier: supplier, created_at: 15.days.ago)
      create(:tire_order, :cancelled, supplier: supplier)

      Rails.cache.clear
    end

    it 'calculates correct order counts' do
      get "/api/v1/suppliers/#{supplier.id}/dashboard", headers: headers

      json = JSON.parse(response.body)
      stats = json['stats']

      # We have: 1 completed, 1 submitted, 1 processing, 3 more completed (from before block), 1 cancelled
      expect(stats['completed_orders']).to eq(4)
      expect(stats['pending_orders']).to eq(1)
      expect(stats['processing_orders']).to eq(1)
      expect(stats['cancelled_orders']).to eq(1)
    end

    it 'includes sync status' do
      get "/api/v1/suppliers/#{supplier.id}/dashboard", headers: headers

      json = JSON.parse(response.body)
      expect(json['stats']).to have_key('last_sync_at')
      expect(json['stats']).to have_key('sync_status')
    end
  end
end
