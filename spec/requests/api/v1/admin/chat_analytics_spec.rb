# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 Admin Chat Analytics', type: :request do
  include RequestSpecHelper

  # Test data
  let(:admin_role) { UserRole.find_or_create_by(name: 'admin') { |role| role.description = 'Administrator' } }
  let(:client_role) { UserRole.find_or_create_by(name: 'client') { |role| role.description = 'Client' } }

  let(:admin_user) { create(:user, role: admin_role) }
  let(:client_user) { create(:user, role: client_role) }

  let(:admin_headers) { authenticate_user(admin_user) }
  let(:client_headers) { authenticate_user(client_user) }

  before do
    # Create test analytics data
    create_list(:chat_analytic, 5, had_results: true, response_type: 'product_recommendation')
    create_list(:chat_analytic, 3, had_results: false, response_type: 'general')
    create_list(:chat_analytic, 2, intent: 'winter_tires', is_quick_question: true)
    create(:chat_analytic, is_brand_comparison: true)
  end

  describe 'GET /api/v1/admin/chat_analytics/summary' do
    context 'when admin requests summary' do
      before do
        get '/api/v1/admin/chat_analytics/summary', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns summary data' do
        expect(json['success']).to be true
        expect(json['data']).to include(
          'total_queries',
          'queries_with_results',
          'queries_without_results',
          'conversion_rate'
        )
      end

      it 'returns period_days' do
        expect(json['period_days']).to eq(30)
      end
    end

    context 'when custom days parameter' do
      before do
        get '/api/v1/admin/chat_analytics/summary', headers: admin_headers, params: { days: 7 }
      end

      it 'uses specified days period' do
        expect(json['period_days']).to eq(7)
      end
    end

    context 'when non-admin requests summary' do
      before do
        get '/api/v1/admin/chat_analytics/summary', headers: client_headers
      end

      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end

    context 'when not authenticated' do
      before do
        get '/api/v1/admin/chat_analytics/summary'
      end

      it 'returns status code 401' do
        expect(response).to have_http_status(401)
      end
    end
  end

  describe 'GET /api/v1/admin/chat_analytics/popular_queries' do
    before do
      # Create specific queries for testing
      create(:chat_analytic, user_query: 'зимние шины', normalized_query: 'зимние шины')
      create(:chat_analytic, user_query: 'зимние шины', normalized_query: 'зимние шины')
      create(:chat_analytic, user_query: 'летние шины', normalized_query: 'летние шины')
    end

    context 'when admin requests popular queries' do
      before do
        get '/api/v1/admin/chat_analytics/popular_queries', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns array of queries with counts' do
        expect(json['success']).to be true
        expect(json['data']).to be_an(Array)
      end
    end

    context 'when limit parameter specified' do
      before do
        get '/api/v1/admin/chat_analytics/popular_queries', headers: admin_headers, params: { limit: 5 }
      end

      it 'respects limit parameter' do
        expect(json['data'].length).to be <= 5
      end
    end

    context 'when non-admin requests' do
      before do
        get '/api/v1/admin/chat_analytics/popular_queries', headers: client_headers
      end

      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /api/v1/admin/chat_analytics/no_results_queries' do
    before do
      create(:chat_analytic, user_query: 'nonexistent tire', had_results: false)
      create(:chat_analytic, user_query: 'nonexistent tire', had_results: false)
    end

    context 'when admin requests no results queries' do
      before do
        get '/api/v1/admin/chat_analytics/no_results_queries', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns array of queries' do
        expect(json['success']).to be true
        expect(json['data']).to be_an(Array)
      end
    end

    context 'when non-admin requests' do
      before do
        get '/api/v1/admin/chat_analytics/no_results_queries', headers: client_headers
      end

      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /api/v1/admin/chat_analytics/intent_distribution' do
    context 'when admin requests intent distribution' do
      before do
        get '/api/v1/admin/chat_analytics/intent_distribution', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns hash of intents with counts' do
        expect(json['success']).to be true
        expect(json['data']).to be_a(Hash)
      end
    end

    context 'when non-admin requests' do
      before do
        get '/api/v1/admin/chat_analytics/intent_distribution', headers: client_headers
      end

      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /api/v1/admin/chat_analytics/daily_stats' do
    context 'when admin requests daily stats' do
      before do
        get '/api/v1/admin/chat_analytics/daily_stats', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns array of daily stats' do
        expect(json['success']).to be true
        expect(json['data']).to be_an(Array)
      end
    end

    context 'when non-admin requests' do
      before do
        get '/api/v1/admin/chat_analytics/daily_stats', headers: client_headers
      end

      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /api/v1/admin/chat_analytics/hourly_distribution' do
    context 'when admin requests hourly distribution' do
      before do
        get '/api/v1/admin/chat_analytics/hourly_distribution', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns hash of hours with counts' do
        expect(json['success']).to be true
        expect(json['data']).to be_a(Hash)
      end
    end

    context 'when non-admin requests' do
      before do
        get '/api/v1/admin/chat_analytics/hourly_distribution', headers: client_headers
      end

      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /api/v1/admin/chat_analytics/response_type_distribution' do
    context 'when admin requests response type distribution' do
      before do
        get '/api/v1/admin/chat_analytics/response_type_distribution', headers: admin_headers
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns hash of response types with counts' do
        expect(json['success']).to be true
        expect(json['data']).to be_a(Hash)
      end
    end

    context 'when non-admin requests' do
      before do
        get '/api/v1/admin/chat_analytics/response_type_distribution', headers: client_headers
      end

      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end
  end
end
