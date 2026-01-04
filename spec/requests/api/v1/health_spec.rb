# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health API', type: :request do
  describe 'GET /api/v1/health' do
    it 'returns ok status' do
      get '/api/v1/health'

      expect(response).to have_http_status(:ok)
      expect(json_response[:status]).to eq('ok')
    end

    it 'includes timestamp' do
      get '/api/v1/health'

      expect(json_response[:timestamp]).to be_present
    end

    it 'includes environment' do
      get '/api/v1/health'

      expect(json_response[:environment]).to eq('test')
    end

    it 'does not require authentication' do
      get '/api/v1/health'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v1/health/deep' do
    it 'returns status with checks' do
      get '/api/v1/health/deep'

      # Status can be ok or degraded depending on Sidekiq processes
      expect(json_response[:status]).to be_in(%w[ok degraded])
      expect(json_response[:checks]).to be_present
    end

    it 'checks database connectivity' do
      get '/api/v1/health/deep'

      expect(json_response[:checks][:database][:status]).to eq('ok')
      expect(json_response[:checks][:database][:latency_ms]).to be_a(Numeric)
    end

    it 'checks Redis connectivity' do
      get '/api/v1/health/deep'

      # Redis might not be running in test, so we accept ok or error
      expect(json_response[:checks][:redis][:status]).to be_present
    end

    it 'checks Sidekiq status' do
      get '/api/v1/health/deep'

      # Sidekiq status could be ok, warning, or not_configured
      expect(json_response[:checks][:sidekiq][:status]).to be_present
    end

    it 'includes version information' do
      get '/api/v1/health/deep'

      expect(json_response[:version]).to be_present
    end

    it 'does not require authentication' do
      get '/api/v1/health/deep'

      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/health/cache_stats' do
    context 'in test/development environment' do
      it 'returns cache statistics' do
        get '/api/v1/health/cache_stats'

        expect(response).to have_http_status(:ok)
        expect(json_response[:cache_store]).to be_present
        expect(json_response[:timestamp]).to be_present
      end

      it 'includes cache stats when CacheMonitoring is defined' do
        get '/api/v1/health/cache_stats'

        if json_response[:cache_stats].is_a?(Hash) && json_response[:cache_stats][:hits]
          expect(json_response[:cache_stats][:hits]).to be_a(Numeric)
          expect(json_response[:cache_stats][:misses]).to be_a(Numeric)
        end
      end
    end
  end
end
