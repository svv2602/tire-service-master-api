# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 Admin Analytics', type: :request do
  include RequestSpecHelper

  # Roles
  let(:admin_role) { UserRole.find_or_create_by(name: 'admin') { |role| role.description = 'Administrator' } }
  let(:client_role) { UserRole.find_or_create_by(name: 'client') { |role| role.description = 'Client' } }

  let(:admin_user) { create(:user, role: admin_role) }
  let(:client_user) { create(:user, role: client_role) }

  let(:admin_headers) { authenticate_user(admin_user) }
  let(:client_headers) { authenticate_user(client_user) }

  describe 'GET /api/v1/admin/analytics/overview' do
    context 'when admin requests overview' do
      before do
        get '/api/v1/admin/analytics/overview', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns overview data structure' do
        expect(json['success']).to be true
        data = json['data']
        expect(data).to include(
          'active_users',
          'bookings',
          'tire_orders',
          'new_partners',
          'new_suppliers',
          'new_clients',
          'bookings_trend'
        )
      end

      it 'returns active users breakdown' do
        users = json['data']['active_users']
        expect(users).to include('total', 'new_in_period', 'active_today')
      end

      it 'returns bookings breakdown' do
        bookings = json['data']['bookings']
        expect(bookings).to include('total', 'pending', 'confirmed', 'completed', 'cancelled')
      end

      it 'returns default period as month' do
        expect(json['period']).to eq('month')
      end
    end

    context 'with custom period' do
      before do
        get '/api/v1/admin/analytics/overview', headers: admin_headers, params: { period: 'week' }
      end

      it 'returns the requested period' do
        expect(json['period']).to eq('week')
      end
    end

    context 'when non-admin user requests' do
      before do
        get '/api/v1/admin/analytics/overview', headers: client_headers
      end

      it 'returns forbidden' do
        expect(response).to have_http_status(403)
      end
    end

    context 'when unauthenticated' do
      before do
        get '/api/v1/admin/analytics/overview'
      end

      it 'returns unauthorized' do
        expect(response).to have_http_status(401)
      end
    end
  end

  describe 'GET /api/v1/admin/analytics/funnel' do
    context 'when admin requests funnel' do
      before do
        get '/api/v1/admin/analytics/funnel', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns funnel steps' do
        expect(json['success']).to be true
        data = json['data']
        expect(data['steps']).to be_an(Array)
        expect(data['steps'].length).to eq(5)
      end

      it 'returns conversion rates' do
        rates = json['data']['conversion_rates']
        expect(rates).to include(
          'search_to_booking',
          'booking_to_confirmed',
          'confirmed_to_completed',
          'completed_to_review'
        )
      end
    end

    context 'when non-admin user requests' do
      before do
        get '/api/v1/admin/analytics/funnel', headers: client_headers
      end

      it 'returns forbidden' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /api/v1/admin/analytics/financial' do
    context 'when admin requests financial data' do
      before do
        get '/api/v1/admin/analytics/financial', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns financial metrics' do
        expect(json['success']).to be true
        data = json['data']
        expect(data).to include(
          'total_revenue',
          'booking_revenue',
          'order_revenue',
          'booking_avg_check',
          'order_avg_check',
          'platform_commission',
          'revenue_trend'
        )
      end

      it 'returns revenue trend as array' do
        expect(json['data']['revenue_trend']).to be_an(Array)
      end
    end

    context 'when non-admin user requests' do
      before do
        get '/api/v1/admin/analytics/financial', headers: client_headers
      end

      it 'returns forbidden' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /api/v1/admin/analytics/geography' do
    context 'when admin requests geography data' do
      before do
        get '/api/v1/admin/analytics/geography', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns geography data as array' do
        expect(json['success']).to be true
        expect(json['data']).to be_an(Array)
      end
    end

    context 'when non-admin user requests' do
      before do
        get '/api/v1/admin/analytics/geography', headers: client_headers
      end

      it 'returns forbidden' do
        expect(response).to have_http_status(403)
      end
    end
  end
end
